(* ::Package:: *)

(* ::Section:: *)
(*dependencies*)


Needs["CCompilerDriver`"]


(* ::Section:: *)
(*gather build data from environment*)


(* 
This section is jenkins-specific for the moment and will be separated from the logic
of the build script as these pieces get abstracted out to a generalized build framework.
This initial implementation will act as boilerplating for the moment. re_build.wl will get
folded into build.wl as soon as this is done. 
*)

env = Association[GetEnvironment[]];
ws = env["WORKSPACE"];
buildPlatform = env["BUILD_PLATFORM"];
creationID = env["CREATIONID"];
job = env["JOB_NAME"];
filesDir = FileNameJoin[{ws, "Files"}];
compilerBin = env["COMPILER_BIN"];
compilerHome = env["COMPILER_HOME"];

(* infer sdkHome from MACOSX_10_11_SDK_HOME *)
If[StringQ[env["MACOSX_10_11_SDK_HOME"]],
	sdkHome = "--sysroot=" <> FileNameJoin[{env["MACOSX_10_11_SDK_HOME"], "MacOSX10.11.sdk"}] <> " ",
	sdkHome = "";
];

(* infer macCompat from MAC_COMPAT *) 
If[StringQ[env["MAC_COMPAT"]],
	macCompat = env["MAC_COMPAT"],
	macCompat = ToString[False];
];

(* infer targetID from JOB_NAME *)
componentName = StringSplit[job, "."][[2]];
targetID = StringSplit[job, "."][[3]];



(* ::Section:: *)
(*component-specific values*)


base = FileNameJoin[{ws, componentName}];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];
cmp = FileNameJoin[{ws, "Components"}];
plat = FileNameJoin[{targetID, buildPlatform}];
extlib = FileNameJoin[{cmp, "libgit2", "0.26.0"}];
libDirs = {FileNameJoin[{extlib, plat}]};
includeDirs = {FileNameJoin[{extlib, "Source", "include"}]};
compileOpts = "";


libDirs = Join[Switch[targetID,
	"Windows"|"Windows-x86-64", {FileNameJoin[{cmp, "LIBSSH2", "1.8.0", targetID, "vc141", "lib"}]},
	"Linux"|"Linux-x86-64", {
		FileNameJoin[{cmp, "OpenSSL", "1.0.2n", targetID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.8.0", targetID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{cmp, "libcurl", "7.57.0", targetID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
], libDirs];


compileOpts = Switch[$OperatingSystem,
	"Windows", "/MT /EHsc",
	"MacOSX", sdkHome <> "-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.9 -framework Security",
	"Unix", "-Wno-deprecated -std=c++14"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "rpcrt4", "shlwapi", "user32", "winhttp", "crypt32", "libssh2"},
	"MacOSX", {"z", "iconv", "curl", "crypto", "ssh2"},
	"Unix", {"z", "rt", "pthread", "ssh2", "ssl", "curl"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[StringMatchQ[targetID, "*64*"], AppendTo[defines, "SIXTYFOURBIT"]];


destDir = FileNameJoin[{filesDir, "GitLink", "LibraryResources", targetID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


(* ::Section:: *)
(*build library*)


If[!StringMatchQ[macCompat,"True"],
lib = CreateLibrary[src, "gitLink",
	"TargetDirectory"->destDir,
	"TargetSystemID"->targetID,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"CompilerName"->compilerBin,
	"CompilerInstallation"->compilerHome,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDirs, srcDirs}],
	"LibraryDirectories"->libDirs,
	"Libraries"->Prepend[oslibs, "git2"],
	"ShellOutputFunction"->Print,
	"ShellCommandFunction"->Print
];

(* we should probably terminate if the compile didn't succeed *)
If[lib === $Failed,
	Print["### ERROR: No library produced. Terminating build... ###"];
	Exit[1]
]];


(* we should probably terminate if the compile didn't succeed *)
If[lib === $Failed,
	Print["### ERROR: No library produced. Terminating build... ###"];
	Exit[1]
]]];


(* ::Section:: *)
(*produce artifact*)


(* 
Using CreateArchive only for zip where we don't care about file permissions.
*)

nativeCreateArchive[src_String, dest_String]:=Module[{res},
	res = RunProcess[{"tar", "czf", dest, src}];
	Return[res];
];

arcName = "Files";

arcFormat = If[$OperatingSystem === "Windows",
	"zip",
	"tar.gz"
];

pack := If[arcFormat === "zip",
	CreateArchive,
	nativeCreateArchive
];

arc = arcName<>"."<>arcFormat;

SetDirectory[filesDir];

archived = pack[componentName, FileNameJoin[{ws,arc}]];

ResetDirectory[];

If[archived === $Failed,
	Print["### ERROR: No archive produced. Terminating build... ###"];
	Exit[1]
];


(* ::Section:: *)
(*generate RE metadata*)


Export[FileNameJoin[{ws,"Build.ini"}],
	{
		"# Build.ini",
		"[job]",
		"name: "<>job,
		"url: "<>env["JOB_URL"],
		"[build]",
		"creationid: "<>creationID,
		"number: "<>env["BUILD_NUMBER"],
		"url: "<>env["BUILD_URL"],
		"[artifact]",
		"name: "<>arc
	},
	{"Text", "Lines"}
]
