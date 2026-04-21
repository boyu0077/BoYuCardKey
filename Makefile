ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.5
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BoYuCardKey
BoYuCardKey_FILES = Tweak.x
BoYuCardKey_FRAMEWORKS = UIKit Foundation
BoYuCardKey_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
