import 'dart:io';

import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;

int get oRdwr => Platform.isMacOS ? macos.O_RDWR : linux.O_RDWR;
int get oWronly => Platform.isMacOS ? macos.O_WRONLY : linux.O_WRONLY;
int get oRdonly => Platform.isMacOS ? macos.O_RDONLY : linux.O_RDONLY;
int get oCreat => Platform.isMacOS ? macos.O_CREAT : linux.O_CREAT;
int get oTrunc => Platform.isMacOS ? macos.O_TRUNC : linux.O_TRUNC;
int get oAppend => Platform.isMacOS ? macos.O_APPEND : linux.O_APPEND;
int get oNoctty => Platform.isMacOS ? macos.O_NOCTTY : linux.O_NOCTTY;
int get oNonblock => Platform.isMacOS ? macos.O_NONBLOCK : linux.O_NONBLOCK;

int get fGetfd => Platform.isMacOS ? macos.F_GETFD : linux.F_GETFD;
int get fSetfd => Platform.isMacOS ? macos.F_SETFD : linux.F_SETFD;
int get fGetfl => Platform.isMacOS ? macos.F_GETFL : linux.F_GETFL;
int get fSetfl => Platform.isMacOS ? macos.F_SETFL : linux.F_SETFL;
int get fdCloexec => Platform.isMacOS ? macos.FD_CLOEXEC : linux.FD_CLOEXEC;

int get tiocswinsz => Platform.isMacOS ? macos.TIOCSWINSZ : linux.TIOCSWINSZ;
int get tiocsctty => Platform.isMacOS ? macos.TIOCSCTTY : linux.TIOCSCTTY;

int get tcsanow => Platform.isMacOS ? macos.TCSANOW : linux.TCSANOW;
int get tcsaflush => Platform.isMacOS ? macos.TCSAFLUSH : linux.TCSAFLUSH;

int get echoBit => Platform.isMacOS ? macos.ECHO : linux.ECHO;
int get echoeBit => Platform.isMacOS ? macos.ECHOE : linux.ECHOE;
int get echokBit => Platform.isMacOS ? macos.ECHOK : linux.ECHOK;
int get echokeBit => Platform.isMacOS ? macos.ECHOKE : linux.ECHOKE;
int get echoctlBit => Platform.isMacOS ? macos.ECHOCTL : linux.ECHOCTL;
int get pendinBit => Platform.isMacOS ? macos.PENDIN : linux.PENDIN;
int get icanonBit => Platform.isMacOS ? macos.ICANON : linux.ICANON;
int get isigBit => Platform.isMacOS ? macos.ISIG : linux.ISIG;
int get iextenBit => Platform.isMacOS ? macos.IEXTEN : linux.IEXTEN;
int get ixonBit => Platform.isMacOS ? macos.IXON : linux.IXON;
int get ixanyBit => Platform.isMacOS ? macos.IXANY : linux.IXANY;
int get icrnlBit => Platform.isMacOS ? macos.ICRNL : linux.ICRNL;
int get inpckBit => Platform.isMacOS ? macos.INPCK : linux.INPCK;
int get istripBit => Platform.isMacOS ? macos.ISTRIP : linux.ISTRIP;
int get imaxbelBit => Platform.isMacOS ? macos.IMAXBEL : linux.IMAXBEL;
int get brkintBit => Platform.isMacOS ? macos.BRKINT : linux.BRKINT;
int get iutf8Bit => Platform.isMacOS ? macos.IUTF8 : linux.IUTF8;
int get opostBit => Platform.isMacOS ? macos.OPOST : linux.OPOST;
int get onlcrBit => Platform.isMacOS ? macos.ONLCR : linux.ONLCR;
int get creadBit => Platform.isMacOS ? macos.CREAD : linux.CREAD;
int get cs8Bits => Platform.isMacOS ? macos.CS8 : linux.CS8;
int get hupclBit => Platform.isMacOS ? macos.HUPCL : linux.HUPCL;

int get cIdxVeof => Platform.isMacOS ? macos.VEOF : linux.VEOF;
int get cIdxVeol => Platform.isMacOS ? macos.VEOL : linux.VEOL;
int get cIdxVerase => Platform.isMacOS ? macos.VERASE : linux.VERASE;
int get cIdxVwerase => Platform.isMacOS ? macos.VWERASE : linux.VWERASE;
int get cIdxVkill => Platform.isMacOS ? macos.VKILL : linux.VKILL;
int get cIdxVreprint => Platform.isMacOS ? macos.VREPRINT : linux.VREPRINT;
int get cIdxVintr => Platform.isMacOS ? macos.VINTR : linux.VINTR;
int get cIdxVquit => Platform.isMacOS ? macos.VQUIT : linux.VQUIT;
int get cIdxVsusp => Platform.isMacOS ? macos.VSUSP : linux.VSUSP;
int get cIdxVstart => Platform.isMacOS ? macos.VSTART : linux.VSTART;
int get cIdxVstop => Platform.isMacOS ? macos.VSTOP : linux.VSTOP;
int get cIdxVlnext => Platform.isMacOS ? macos.VLNEXT : linux.VLNEXT;
int get cIdxVdiscard => Platform.isMacOS ? macos.VDISCARD : linux.VDISCARD;
int get cIdxVmin => Platform.isMacOS ? macos.VMIN : linux.VMIN;
int get cIdxVtime => Platform.isMacOS ? macos.VTIME : linux.VTIME;
