PREFIX  ?=
DESTDIR ?=

SRC := attach.c blame.c bootstrap.c enable.c env.c error.c examine.c kickstart.c
SRC += kill.c launchctl.c limit.c list.c load.c manager.c plist.c print.c reboot.c
SRC += remove.c runstats.c start_stop.c userswitch.c version.c xpc_helper.c
SRC += plistpatch.m

CFLAGS += -fobjc-arc -Werror 

ifeq ($(DEBUG),1)
CFLAGS  += -O0 -g -fsanitize=address,undefined -fno-omit-frame-pointer
LDFLAGS += -O0 -g -fsanitize=address,undefined -fno-omit-frame-pointer
endif

all: launchctl

%.o: %.m
	$(CC) $(CFLAGS) -c $< -o $@

launchctl: $(SRC:.c=.o) $(SRC:.m=.o) Info.plist launchctl.xml
	$(CC) $(CFLAGS) $(LDFLAGS) $(filter %.o,$^) $(LOADLIBES) $(LDLIBS) -o $@ -Wl,-sectcreate,__TEXT,__info_plist,Info.plist
	ldid -Icom.apple.xpc.launchctl -Slaunchctl.xml -Cadhoc launchctl

clean:
	rm -rf launchctl launchctl.dSYM *.o

install: launchctl
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m755 launchctl $(DESTDIR)$(PREFIX)/bin/launchctl

.PHONY: all clean install
