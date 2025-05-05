$(call inherit-product, device/phh/treble/base.mk)
$(call inherit-product, vendor/voltage/config/common_full_phone.mk)
$(call inherit-product, vendor/voltage/config/BoardConfigSoong.mk)
$(call inherit-product, device/voltage/sepolicy/common/sepolicy.mk)

# Animations
TARGET_BOOT_ANIMATION_RES := 1080

# Kernel
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
TARGET_NO_KERNEL_IMAGE := true
TARGET_NO_KERNEL_OVERRIDE := true

# Overlay
PRODUCT_PACKAGE_OVERLAYS += \
   $(LOCAL_PATH)/overlay-voltage

# Packages
PRODUCT_PACKAGES += \
  AppStore \
  AuroraStorePrivilegedExtension \
  F-DroidPrivilegedExtension \
  OpenEUICC

# Product
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
PRODUCT_CHARACTERISTICS := device

# SELinux
TARGET_USES_PREBUILT_VENDOR_SEPOLICY := true
