GO_EASY_ON_ME = 1

THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

ARCHS = arm64 armv7s armv7
TARGET = iphone:clang:latest:7.0

include theos/makefiles/common.mk

TWEAK_NAME = Spectral
Spectral_LIBRARIES = substrate
Spectral_FILES = Tweak.xm SBBlurryArtworkView.m
Spectral_CFLAGS = -fobjc-arc
Spectral_FRAMEWORKS = Foundation CoreGraphics QuartzCore UIKit MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk


after-install::
	install.exec "killall -9 backboardd"
