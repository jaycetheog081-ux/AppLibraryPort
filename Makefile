ARCHS = arm64
TARGET = iphone:clang:latest:12.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AppLibrary12

AppLibrary12_FILES = Tweak.xm AppLibrary12ViewController.m
AppLibrary12_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AppLibrary12_FRAMEWORKS = UIKit Foundation

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
