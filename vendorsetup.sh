# OrangeFox build variables for tucana (Mi Note 10 / Mi Note 10 Pro).
#
# build/envsetup.sh sources the vendorsetup.sh of every device in the tree.
# The variables are exported only when TARGET_PRODUCT is twrp_tucana, so
# they do not leak into the builds of other devices sharing the same source
# tree. OrangeFox saves the environment to /tmp/<device>/fox_env.sh during
# lunch, so a build script has to set TARGET_PRODUCT and source this file
# before running lunch.
if [ "$TARGET_PRODUCT" = "twrp_tucana" ]; then
	# Device name
	export FOX_BUILD_DEVICE="tucana"

	# Versioning and Maintainer
	export FOX_VARIANT="Retrofit"
	export FOX_MAINTAINER_PATCH_VERSION="1"
	export OF_MAINTAINER="LIECOTI"

	# Hardware specifics
	export FOX_AB_DEVICE=0
	export FOX_VIRTUAL_AB_DEVICE=0
	export OF_PATCH_AVB20=1
	export FOX_RECOVERY_INSTALL_PARTITION="/dev/block/bootdevice/by-name/recovery"
	export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"
	export OF_SCREEN_H=2340
	export OF_SCREEN_W=1080
	# curved bottom edge: keep the lock-screen swipe and navigation buttons clear of it
	export OF_SCREEN_BOTTOM_INSET=60

	# Additional tools
	export FOX_ENABLE_APP_MANAGER=1
	export OF_ENABLE_LPTOOLS=1

	# Screen notch/cutout configuration
	export OF_STATUS_H=60
	export OF_STATUS_INDENT_LEFT=64
	export OF_STATUS_INDENT_RIGHT=64
	export OF_CLOCK_POS=1

	# Fix for reboot loop and vanilla build
	export FOX_VANILLA_BUILD=1
	export FOX_REPLACE_TOOLBOX_GETPROP=1
fi
