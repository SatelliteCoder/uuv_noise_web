# UUV 目标辐射噪声 Web 本地原型

这是一个不写入 GitHub 仓库的本地第一版系统，位置：

```text
E:\HJ\uuv_noise_web_local
```

## 启动

在 PowerShell 中运行：

```powershell
cd E:\HJ\uuv_noise_web_local
python .\backend\server.py
```

浏览器打开：

```text
http://127.0.0.1:8765
```

## 第一版功能

- 前端：参数表单、点源/线源/面源/体源/全部四类选择、结果图展示、WAV 播放、CSV/MAT/TXT 下载。
- 后端：Python 标准库 HTTP 服务，不依赖 FastAPI/Node。
- 计算内核：本地复制的 MATLAB 半经验 UUV 目标辐射噪声模型。
- 输出目录：`jobs/<任务ID>/`，每次运行单独保存结果。

## 输出噪声是什么

生成的是 UUV 目标辐射噪声半经验信号，不是任意白噪声。信号组成包括：

- 机械宽带噪声；
- 机械/电机线谱；
- 轴频线谱；
- 螺旋桨叶频 BPF 及倍频线谱；
- 带 DEMON 调制特征的螺旋桨/空泡宽带噪声；
- 艇体流噪声宽带成分。

`uuv_source_signal.wav` 是 1 m 等效源信号预览。
`uuv_received_target.wav` 是简化传播后的目标信号预览。
`uuv_received_mix.wav` 是目标信号加背景噪声的接收端混合预览。

## 重要限制

本项目是工程原型。默认参数只用于算法链路验证和可视化演示，未经过真实 UUV 实测数据标定，不能视为特定装备的真实声学指纹。
