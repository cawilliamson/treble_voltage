$(call inherit-product, vendor/voltage/config/common_full_phone.mk)
$(call inherit-product, vendor/voltage/config/BoardConfigSoong.mk)
$(call inherit-product, vendor/voltage/config/BoardConfigVoltage.mk)
$(call inherit-product, device/voltage/sepolicy/common/sepolicy.mk)
-include vendor/voltage/build/core/config.mk

TARGET_NO_KERNEL_OVERRIDE := true
TARGET_NO_KERNEL_IMAGE := true
SELINUX_IGNORE_NEVERALLOWS := true
TARGET_BOOT_ANIMATION_RES := 1280

TARGET_USES_PREBUILT_VENDOR_SEPOLICY := true
BOARD_EXT4_SHARE_DUP_BLOCKS := true

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.system.ota.json_url=https://raw.githubusercontent.com/cawilliamson/treble_voltage/14.0/ota.json

PRODUCT_PACKAGE_OVERLAYS += \
   $(LOCAL_PATH)/overlay-voltage
