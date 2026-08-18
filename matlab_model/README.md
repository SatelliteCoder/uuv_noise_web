# UUV 目标辐射噪声半经验模型

这是一个 MATLAB 版 UUV/小型水下目标辐射噪声源模型，用于三维声场仿真系统中的“目标噪声源建模”模块。

模型支持四种空间等效声源：

```text
point   点声源
line    线声源
surface 面声源
volume  体积源
```

## 生成的是什么噪声

生成的不是任意白噪声，也不是单纯的螺旋桨噪声，而是一个 **UUV 目标辐射噪声半经验组合模型**：

```text
s_uuv(t) = 机械宽带噪声
         + 机械/电机线谱
         + 轴频线谱
         + 螺旋桨叶频 BPF 及倍频线谱
         + 螺旋桨/空化调制宽带噪声
         + 壳体/航行流噪声
```

其中：

```text
机械噪声：电机、轴系、泵、结构传递等宽带和线谱分量
螺旋桨噪声：轴频、叶频 BPF、BPF 倍频线谱
空化噪声：经过轴频/BPF 包络调制的宽带噪声，可形成 DEMON 特征
流噪声：艇体航行产生的宽带流动噪声
```

所以，如果你问“这是螺旋桨噪声吗”，准确回答是：

> 它包含螺旋桨/叶频/空化噪声，但不是只有螺旋桨噪声；它是 UUV 目标辐射噪声的组合模型。

## 按需运行

先在 MATLAB 中进入本目录：

```matlab
cd('你的项目路径/uuv_source_model')
```

只跑点声源：

```matlab
run_point_source_noise
```

只跑线声源：

```matlab
run_line_source_noise
```

只跑面声源：

```matlab
run_surface_source_noise
```

只跑体积源：

```matlab
run_volume_source_noise
```

四种声源一起跑：

```matlab
run_all_source_types
```

单独运行时，只会生成对应类型的输出。例如：

```text
output/point
output/line
output/surface
output/volume
```

## 四种等效声源的含义

### point 点声源

适合远场、小尺寸目标、快速仿真。源元素只有一个：

```text
source.center_xyz_m
```

### line 线声源

沿 UUV 艇体长轴布置多个源元素，适合模拟长条形艇体、轴系、推进轴方向的噪声分布。

### surface 面声源

在圆柱形艇体壳面布置源元素，适合模拟艇体壳面、推进器外表面等效辐射。

### volume 体积源

在艇体内部体积中布置源元素，适合模拟内部机械、舱段、结构振动等体积分布噪声。

## 主要入口

### `run_uuv_source_case`

通用运行入口：

```matlab
result = run_uuv_source_case('point');
result = run_uuv_source_case('line');
result = run_uuv_source_case('surface');
result = run_uuv_source_case('volume');
```

也可以先修改参数再运行：

```matlab
params = uuv_default_params();
params.uuv.rpm = 900;
params.uuv.speed_mps = 4.0;
result = run_uuv_source_case('line', params);
```

### `uuv_default_params`

生成默认参数：

```matlab
params = uuv_default_params();
```

常用参数：

```matlab
params.fs = 48000;
params.duration_s = 12;

params.uuv.length_m = 3.2;
params.uuv.diameter_m = 0.45;
params.uuv.speed_mps = 3.0;
params.uuv.depth_m = 50;
params.uuv.rpm = 720;
params.uuv.blade_count = 4;
params.uuv.propeller_diameter_m = 0.24;

params.source.type = 'volume';
params.source.center_xyz_m = [0 0 -50];
params.source.heading_deg = 20;

params.geometry.receiver_xyz_m = [600 160 -45];
```

### `uuv_run_model`

核心模型入口：

```matlab
result = uuv_run_model(params);
```

完成：

```text
生成源级谱 SL(f)
生成 UUV 时域源信号
构建点/线/面/体积源元素
做简化传播预览
叠加接收端背景噪声
返回 result 结构体
```

### `uuv_source_spectrum`

生成源级谱：

```matlab
spectrum = uuv_source_spectrum(params, n);
```

输出：

```matlab
spectrum.f_hz
spectrum.total_db
spectrum.machine_db
spectrum.prop_db
spectrum.flow_db
spectrum.tones
spectrum.features.shaft_hz
spectrum.features.bpf_hz
spectrum.features.cavitation_activity
```

### `uuv_synthesize_source_signal`

从源级谱合成时域信号：

```matlab
source = uuv_synthesize_source_signal(params, spectrum, t);
```

输出：

```matlab
source.source_signal_uPa
source.machine_noise_uPa
source.prop_noise_uPa
source.flow_noise_uPa
source.tonal_uPa
source.envelope
```

### `uuv_source_geometry`

生成等效声源几何元素：

```matlab
geometry = uuv_source_geometry(params);
```

输出：

```matlab
geometry.type
geometry.center_xyz_m
geometry.element_xyz_m
geometry.weight
geometry.num_elements
geometry.local_xyz_m
```

### `uuv_apply_propagation`

简化传播预览：

```matlab
[y, propagation] = uuv_apply_propagation(x, fs, source_f_hz, params, geometry);
```

当前实现：

```text
时域波形预览：
y(t) = sum_i gain_i * x(t - delay_i)

频域传播损失预览：
TL_i(f) = 20 log10(r_i) + alpha(f) r_i
TL_equiv(f) = -10 log10(sum_i weight_i * 10^(-TL_i(f)/10))
```

这个传播函数只是预览接口。正式三维声场系统中，应替换为 Bellhop / RAM / Kraken / 自研三维传播模块输出的：

```text
TL(f, source_element, receiver)
```

## 输出文件

每次运行会在对应输出目录中生成：

```text
uuv_noise_description.txt      噪声类型说明和关键特征
uuv_source_model_result.mat    完整结果结构体
uuv_source_spectrum.csv        源级谱、传播损失、接收级预览
uuv_tonal_lines.csv            轴频、BPF、电机线谱
uuv_source_geometry.csv        源元素坐标、权重、距离、延迟
uuv_source_signal.wav          1 m 等效源信号
uuv_received_target.wav        简化传播后的目标信号
uuv_received_mix.wav           目标 + 背景预览信号
uuv_source_spectrum.png        源级谱图
uuv_waveforms.png              波形图
uuv_spectrogram.png            时频图
uuv_lofar.png                  LOFAR 风格低频图
uuv_demon.png                  DEMON 包络谱
uuv_source_geometry_3d.png     左侧传播总览，右侧源几何局部放大
uuv_summary.png                汇总图
```

## 对接三维声场传播

频域对接时使用：

```matlab
f = result.spectrum.f_hz;
SL = result.spectrum.total_db;
src_xyz = result.geometry.element_xyz_m;
src_w = result.geometry.weight;
rx_xyz = params.geometry.receiver_xyz_m;
```

传播模型给出：

```text
TL(f, source_element, receiver)
```

然后得到：

```text
RL(f) = SL(f) - TL(f)
```

时域对接时使用：

```matlab
s = result.source.source_signal_uPa;
src_xyz = result.geometry.element_xyz_m;
src_w = result.geometry.weight;
```

对每个源元素求传播冲激响应 `h_i(t)`：

```text
y(t) = sum_i sqrt(w_i) * conv(s(t), h_i(t))
```

再叠加海洋背景噪声：

```text
r(t) = y_target(t) + n_ambient(t)
```

## 当前模型边界

已经完成：

```text
UUV 目标辐射噪声谱生成
时域噪声合成
机械/轴频/BPF/空化/流噪分量
点源/线源/面源/体积源空间等效
简化传播预览
LOFAR / DEMON / 三维几何渲染
接口文件导出
```

尚未完成：

```text
真实 UUV 实测数据标定
CFD/FW-H 螺旋桨流噪离线标定
复杂海洋环境多径传播
频率相关指向性数据库
多接收阵列波束形成
```

