-- Environmental variables (for reference https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/)
-- if you use UWSM, define your variables in ~/.config/uwsm/env
-- if you don't use UWSM, define your variables here (e.g. hl.env("QT_QPA_PLATFORM", "wayland"))

-- Only drive displays from the AMD iGPU (udev symlink, see /etc/udev/rules.d/61-amd-igpu.rules)
-- so the NVIDIA dGPU can power off / be switched to Integrated by supergfxctl.
-- Apps can still use NVIDIA via prime-run.
if io.open("/dev/dri/amd-igpu") then hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu") end

-- if you have an NVIDIA GPU uncomment the following lines:

-- hl.env("GBM_BACKEND", "nvidia-drm") -- force GBM as a backend
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- force GBM as a backend
-- hl.env("LIBVA_DRIVER_NAME", "nvidia") -- Hardware acceleration on NVIDIA GPUs
-- hl.env("__GL_GSYNC_ALLOWED", "1") -- Controls if G-Sync capable monitors should use Variable Refresh Rate (VRR)
