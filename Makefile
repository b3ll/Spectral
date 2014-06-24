ARCHS = arm64 armv7s armv7
GO_EASY_ON_ME = 1

THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

ADDITIONAL_CFLAGS = -fobjc-arc

include theos/makefiles/common.mk

TWEAK_NAME = Spectral
Spectral_LIBRARIES = substrate
Spectral_FILES = Tweak.xm SBBlurryArtworkView.m
Spectral_FRAMEWORKS = Foundation CoreGraphics QuartzCore UIKit MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk


after-install::
	install.exec "killall -9 backboardd"
