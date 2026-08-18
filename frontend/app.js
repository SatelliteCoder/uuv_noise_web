const sourceLabels = {
  point: "点源",
  line: "线源",
  surface: "面源",
  volume: "体源",
  all: "全部四类",
};

let selectedSource = "point";
let pollTimer = null;

const $ = (id) => document.getElementById(id);

function numberValue(id) {
  const value = Number($(id).value);
  return Number.isFinite(value) ? value : undefined;
}

function collectConfig() {
  return {
    source_type: selectedSource,
    fs: numberValue("fs"),
    duration_s: numberValue("duration_s"),
    random_seed: numberValue("random_seed"),
    uuv: {
      length_m: numberValue("length_m"),
      diameter_m: numberValue("diameter_m"),
      depth_m: numberValue("depth_m"),
      speed_mps: numberValue("speed_mps"),
      rpm: numberValue("rpm"),
      blade_count: numberValue("blade_count"),
      propeller_diameter_m: numberValue("propeller_diameter_m"),
    },
    source: {
      line_elements: numberValue("line_elements"),
      surface_axial_elements: numberValue("surface_axial_elements"),
      surface_circum_elements: numberValue("surface_circum_elements"),
      volume_axial_elements: numberValue("volume_axial_elements"),
      volume_radial_elements: numberValue("volume_radial_elements"),
      volume_circum_elements: numberValue("volume_circum_elements"),
    },
    receiver: {
      x_m: numberValue("receiver_x_m"),
      y_m: numberValue("receiver_y_m"),
      z_m: numberValue("receiver_z_m"),
    },
    ambient: {
      enabled: $("ambient_enabled").checked,
      rms_uPa: numberValue("ambient_rms_uPa"),
      slope_db_decade: numberValue("ambient_slope_db_decade"),
    },
  };
}

function formatNumber(value, digits = 2) {
  if (typeof value !== "number" || !Number.isFinite(value)) return "-";
  return value.toFixed(digits);
}

function fileUrl(caseData, key) {
  return caseData.file_urls && caseData.file_urls[key] ? caseData.file_urls[key] : "";
}

function metric(label, value, unit = "", digits = 2) {
  return `
    <div class="metric">
      <span>${label}</span>
      <strong>${formatNumber(value, digits)}${unit}</strong>
    </div>
  `;
}

function imageCard(title, url) {
  if (!url) return "";
  return `
    <article class="media-card">
      <h4>${title}</h4>
      <img src="${url}" alt="${title}" loading="lazy" />
    </article>
  `;
}

function audioItem(title, url) {
  if (!url) return "";
  return `
    <div class="audio-item">
      <span>${title}</span>
      <audio controls src="${url}"></audio>
    </div>
  `;
}

function fileLink(title, url) {
  if (!url) return "";
  return `<a class="file-link" href="${url}" target="_blank" rel="noreferrer"><span>${title}</span>${url.split("/").pop()}</a>`;
}

function renderCase(caseData) {
  const features = caseData.features || {};
  const metrics = caseData.metrics || {};
  const geometry = caseData.geometry || {};
  const components = Array.isArray(caseData.noise_components)
    ? caseData.noise_components.join("、")
    : "机械宽带/线谱、轴频/BPF 螺旋桨线谱、DEMON 调制空泡宽带、流噪声";

  return `
    <article class="case-card">
      <div class="case-title">
        <h3>${caseData.source_type_label || sourceLabels[caseData.source_type] || caseData.source_type}</h3>
        <span>${geometry.num_elements || "-"} 个离散声源单元，耗时 ${formatNumber(caseData.elapsed_s, 1)} s</span>
      </div>
      <div class="metrics">
        ${metric("轴频", features.shaft_hz, " Hz", 2)}
        ${metric("叶频 BPF", features.bpf_hz, " Hz", 2)}
        ${metric("空泡活动指数", features.cavitation_activity, "", 2)}
        ${metric("接收预览 SNR", metrics.preview_snr_db, " dB", 2)}
      </div>
      <div class="components">
        输出噪声：UUV 目标辐射噪声半经验信号，包含 ${components}。其中 received_mix 额外叠加背景噪声，仅用于接收端混合预览。
      </div>
      <div class="media-grid">
        ${imageCard("总览", fileUrl(caseData, "summary_png"))}
        ${imageCard("源级谱", fileUrl(caseData, "spectrum_png"))}
        ${imageCard("时域波形", fileUrl(caseData, "waveforms_png"))}
        ${imageCard("LOFAR", fileUrl(caseData, "lofar_png"))}
        ${imageCard("DEMON", fileUrl(caseData, "demon_png"))}
        ${imageCard("三维等效源几何", fileUrl(caseData, "geometry_png"))}
      </div>
      <div class="audio-list">
        ${audioItem("1 m 等效源信号", fileUrl(caseData, "source_wav"))}
        ${audioItem("传播后目标预览", fileUrl(caseData, "received_target_wav"))}
        ${audioItem("目标 + 背景混合预览", fileUrl(caseData, "received_mix_wav"))}
      </div>
      <div class="file-list">
        ${fileLink("源级谱 CSV", fileUrl(caseData, "spectrum_csv"))}
        ${fileLink("线谱表 CSV", fileUrl(caseData, "tones_csv"))}
        ${fileLink("几何 CSV", fileUrl(caseData, "geometry_csv"))}
        ${fileLink("MAT 结果", fileUrl(caseData, "mat_result"))}
        ${fileLink("说明 TXT", fileUrl(caseData, "description_txt"))}
        ${fileLink("MATLAB 日志", fileUrl(caseData, "log_file"))}
      </div>
    </article>
  `;
}

function renderJob(job) {
  const area = $("resultArea");
  const folderLink = $("jobFolderLink");
  $("statusText").textContent = job.message || job.status;
  $("resultSubtitle").textContent = `任务 ${job.job_id}：${job.message || job.status}`;

  if (job.status === "failed") {
    area.className = "error-box";
    area.textContent = job.message || "仿真失败";
    folderLink.classList.add("hidden");
    return;
  }

  if (job.status !== "succeeded") {
    area.className = "empty-state";
    area.innerHTML = `<strong>${job.message || "运行中"}</strong><span>MATLAB 正在生成 wav、png、csv 和 mat 文件。</span>`;
    folderLink.classList.add("hidden");
    return;
  }

  area.className = "case-grid";
  const cases = Array.isArray(job.cases) ? job.cases : [];
  area.innerHTML = cases.map(renderCase).join("");
  folderLink.href = `/jobs/${job.job_id}/web_job_summary.json`;
  folderLink.textContent = "下载任务总览";
  folderLink.classList.remove("hidden");
}

async function pollJob(jobId) {
  try {
    const response = await fetch(`/api/jobs/${jobId}`);
    const job = await response.json();
    renderJob(job);
    if (job.status === "succeeded" || job.status === "failed") {
      clearInterval(pollTimer);
      pollTimer = null;
      $("runButton").disabled = false;
    }
  } catch (error) {
    $("statusText").textContent = String(error);
  }
}

async function startJob(event) {
  event.preventDefault();
  clearInterval(pollTimer);
  $("runButton").disabled = true;
  $("statusText").textContent = `提交 ${sourceLabels[selectedSource]} 仿真`;
  $("resultArea").className = "empty-state";
  $("resultArea").innerHTML = "<strong>已提交</strong><span>后端正在启动 MATLAB。</span>";

  try {
    const response = await fetch("/api/jobs", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(collectConfig()),
    });
    const job = await response.json();
    renderJob(job);
    pollTimer = setInterval(() => pollJob(job.job_id), 2000);
    pollJob(job.job_id);
  } catch (error) {
    $("runButton").disabled = false;
    $("resultArea").className = "error-box";
    $("resultArea").textContent = String(error);
  }
}

async function checkHealth() {
  const badge = $("healthBadge");
  try {
    const response = await fetch("/api/health");
    const health = await response.json();
    badge.textContent = health.matlab_found ? "MATLAB 可用" : "未找到 MATLAB";
    badge.className = `badge ${health.matlab_found ? "ok" : "bad"}`;
  } catch {
    badge.textContent = "后端未连接";
    badge.className = "badge bad";
  }
}

document.querySelectorAll("#sourceSelector button").forEach((button) => {
  button.addEventListener("click", () => {
    selectedSource = button.dataset.source;
    document.querySelectorAll("#sourceSelector button").forEach((item) => {
      item.classList.toggle("active", item === button);
    });
  });
});

$("simForm").addEventListener("submit", startJob);
checkHealth();
