(* ::Package:: *)

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
extlib = FileNameJoin[{ws, "Components", "libgit2", "0.21.3"}];
libDirs = {FileNameJoin[{extlib, targetID, buildPlatform}]};
includeDir = FileNameJoin[{extlib, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/MT /EHsc",
	"MacOSX", "-std=c++11 -stdlib=libc++ -mmacosx-version-min=10.7",
	"Unix", "-Wno-deprecated -std=c++11"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "user32", "shlwapi"},
	"MacOSX", {"ssl", "z", "iconv", "crypto"},
	"Unix", {"z", "dl", "rt"}
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
(*	"ShellOutputFunction"->Print,*)
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"CompilerName"->compilerBin,
	"CompilerInstallation"->compilerHome,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirs,
	"Libraries"->Prepend[oslibs, "git2"],
	"ShellOutputFunction"->Print,
	"ShellCommandFunction"->Print
]


(* ::Section:: *)
(*produce artifact*)


(* 
Going to be super confident about our wonderful software and attempt to use CreateArchive 
for now... 
*)

arcName = "Files";

If[$OperatingSystem === "Windows",
	arcFormat = ".zip",
	arcFormat = ".tar.gz";
];

arc = arcName<>arcFormat;

SetDirectory[filesDir];

CreateArchive[componentName, FileNameJoin[{ws,arc}]];

ResetDirectory[];


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
