(* ::Package:: *)

$Debug = False;


Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.28.3"}];
environmentNewSSL = Switch[$SystemID,
	"Windows-x86-64", "vc140",
	"MacOSX-x86-64", "libcxx-min10.12",
	"MacOSX-ARM64", "libcxx-min11.0",
	"Linux-x86-64", "scientific6-gcc7.3"
];
libDirsNewSSL = {FileNameJoin[{component, $SystemID, environmentNewSSL}]};

(* Try to use $InstallationDirecotry as a backup for some libraries *)
AppendTo[libDirsNewSSL, FileNameJoin[{$InstallationDirectory, "SystemFiles", "Libraries", $SystemID}]];
If[$Debug,
	PrependTo[libDirsNewSSL, FileNameJoin[{component, $SystemID, environmentNewSSL<>".debug"}]]';
];

libDirsNewSSL = Join[Switch[$SystemID,
	"Windows-x86-64", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.10.0", $SystemID, "vc141", "lib"}]},
	"MacOSX-x86-64", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.1.1q", $SystemID, "libcxx-min10.14", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.10.0", $SystemID, "libcxx-min10.14", "lib"}]
	},
	"MacOSX-ARM64", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.1.1q", $SystemID, "libcxx-min11.0", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.10.0", $SystemID, "libcxx-min11.0", "lib"}]
	},
	"Linux-x86-64", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.1.1q", $SystemID, "nocona-glibc2.17", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.10.0", $SystemID, "nocona-glibc2.17", "lib"}]
	},
	_, {}
], libDirsNewSSL];
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/EHsc /MT" <> If[$Debug, "D", ""],
	"MacOSX", "-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.14 -framework Security",
	"Unix", "-Wno-deprecated -std=c++14"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "rpcrt4", "shlwapi", "user32", "winhttp", "crypt32", "libssh2"},
	"MacOSX", {"z", "iconv", "crypto", "ssh2"},
	"Unix", {"z", "rt", "pthread", "ssh2", "ssl"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[$SystemWordLength===64, AppendTo[defines, "SIXTYFOURBIT"]];
If[$Debug, AppendTo[defines, "DEBUG"]];


destDir = FileNameJoin[{base, "GitLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


libNewSSL = CreateLibrary[src, "gitLink",
(*	"ShellOutputFunction"->Print,*)
	"Debug"->$Debug,
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirsNewSSL,
	"Libraries"->Prepend[oslibs, "git2"]
]

