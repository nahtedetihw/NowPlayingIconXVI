TARGET := iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
SYSROOT = $(THEOS)/sdks/iPhoneOS14.2.sdk
PREFIX=$(THEOS)/toolchain/Xcode.xctoolchain/usr/bin/
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NowPlayingIconXVI

NowPlayingIconXVI_FILES = NowPlayingIconXVI.xm
NowPlayingIconXVI_CFLAGS = -fobjc-arc
NowPlayingIconXVI_PRIVATE_FRAMEWORKS = MediaRemote

include $(THEOS_MAKE_PATH)/tweak.mk
