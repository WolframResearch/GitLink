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

(* infer targetID from JOB_NAME *)
componentName = StringSplit[job, "."][[2]];
targetID = StringSplit[job, "."][[3]];



(* ::Section:: *)
(*component-specific values*)


base = FileNameJoin[{ws, componentName}];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];
cmp = FileNameJoin[{ws, "Components"}];
includeDirs = {FileNameJoin[{cmp, "libgit2", "0.28.3", "Source", "include"}]};
compileOpts = "";


libDirs = Switch[targetID,
	"Windows"|"Windows-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "vc140"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.9.0", targetID, "vc141", "lib"}]
	},
	"MacOSX-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "libcxx-min10.12"}],
		FileNameJoin[{cmp, "OpenSSL", "1.1.1c", targetID, "libcxx-min10.12", "lib"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.9.0", targetID, "libcxx-min10.12", "lib"}]
	},
	"Linux"|"Linux-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "scientific6-gcc7.3"}],
		FileNameJoin[{cmp, "OpenSSL", "1.1.1c", targetID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.9.0", targetID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
];


libDirsOldSSL = Switch[targetID,
	"Windows"|"Windows-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "vc140.ssl100"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.8.0", targetID, "vc141", "lib"}]
	},
	"MacOSX-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "libcxx-min10.12.ssl100"}],
		FileNameJoin[{cmp, "OpenSSL", "1.0.2s", targetID, "libcxx-min10.9", "lib"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.8.0", targetID, "libcxx-min10.9", "lib"}]
	},
	"Linux"|"Linux-x86-64", {
		FileNameJoin[{cmp, "libgit2", "0.28.3", targetID, "scientific6-gcc7.3.ssl100"}],
		FileNameJoin[{cmp, "OpenSSL", "1.0.2s", targetID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{cmp, "LIBSSH2", "1.8.0", targetID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
];


compileOpts = Switch[$OperatingSystem,
	"Windows", "/MT /EHsc",
	"MacOSX", "-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.9 -framework Security",
	"Unix", "-Wno-deprecated -std=c++14"];
linkerOpts = Switch[$OperatingSystem,
	"MacOSX", {"-install_name", "@rpath/gitLink.dylib", "-rpath", "@loader_path"},
	"Unix", {"-rpath='$ORIGIN'"},
	"Windows", {"/NODEFAULTLIB:msvcrt"},
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
If[StringMatchQ[targetID, "*64*"], AppendTo[defines, "SIXTYFOURBIT"]];


destDir = FileNameJoin[{filesDir, "GitLink", "LibraryResources", targetID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


(* ::Section:: *)
(*build library*)


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
];

lib_ssl100 = CreateLibrary[src, "gitLink_ssl100",
	"TargetDirectory"->destDir,
	"TargetSystemID"->targetID,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"CompilerName"->compilerBin,
	"CompilerInstallation"->compilerHome,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDirs, srcDirs}],
	"LibraryDirectories"->libDirsOldSSL,
	"Libraries"->Prepend[oslibs, "git2"],
	"ShellOutputFunction"->Print,
	"ShellCommandFunction"->Print
];

(* we should probably terminate if the compile didn't succeed *)
If[lib_ssl100 === $Failed,
	Print["### ERROR: No gitLink_ssl100 library produced. Terminating build... ###"];
	Exit[1]
];


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
