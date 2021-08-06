(* ::Package:: *)

(* ::Title:: *)
(*Assemble the paclet, and build a new .paclet file*)


(* ::Section:: *)
(*Find directory locations*)


date = DateString[{"Year", "Month", "Day"}];
time = DateString[{"Hour24", "Minute", "Second"}];

$versionNumber = If[Environment["SET_VERSION_NUMBER"] =!= $Failed,
	Environment["SET_VERSION_NUMBER"],
	"0.0."<>date<>"."<>time
];

$kernelDirectory = Which[
	Environment["WORKSPACE"] =!= $Failed,
		FileNameJoin[{Environment["WORKSPACE"],"GitLink","GitLink","Kernel"}],
	$InputFileName =!= "",
		DirectoryName[$InputFileName],
	True,
		NotebookDirectory[]
];

$templateFile = FileNameJoin[{ParentDirectory[$kernelDirectory], "PacletInfoTemplate.m"}];

$inputDirectory = Which[
	Environment["WORKSPACE"] =!= $Failed,
		FileNameJoin[{Environment["WORKSPACE"],"output","Files"}],
	$InputFileName =!= "",
		DirectoryName[$InputFileName],
	True,
		NotebookDirectory[]
];

$outputDirectory = FileNameJoin[{$inputDirectory, date <> "-" <> time}];

(*$source = FileNameJoin[{$outputDirectory, "source"}]*)
$assembled = FileNameJoin[{$outputDirectory, "assembled", "GitLink"}];

(*CreateDirectory[$source, CreateIntermediateDirectories -> True];*)
CreateDirectory[$assembled, CreateIntermediateDirectories -> True];


(* ::Section:: *)
(*Copy files to be assembled into assembly directory*)


CopyDirectory[$kernelDirectory, FileNameJoin[{$assembled, "Kernel"}]];
CopyDirectory[FileNameJoin[{$inputDirectory, "GitLink", "Documentation"}], FileNameJoin[{$assembled, "Documentation"}]];
CopyDirectory[FileNameJoin[{$inputDirectory, "GitLink", "LibraryResources"}], FileNameJoin[{$assembled, "LibraryResources"}]];


(* ::Section:: *)
(*Assemble the paclet*)


(*$sourceFolderSet = {"Documentation", "Kernel", "LibraryResources"};

CopyDirectory[ToFileName[{$source, #}], ToFileName[{$assembled, #}]]& /@ $sourceFolderSet;
*)
FileTemplateApply[
	FileTemplate[$templateFile],
	<| "Version" -> $versionNumber, "SystemID" -> "", "Qualifier" -> "" |>,
	FileNameJoin[{$assembled, "PacletInfo.m"}]
];

(* get rid of any .DS* files or other hidden files *)
DeleteFile /@ FileNames[".*", $assembled, Infinity];


(* ::Section:: *)
(*Create .paclet file*)


PackPaclet[$assembled];
$pacletName = FileNameTake[FileNames["*.paclet",ParentDirectory[$assembled]][[1]]];
CopyFile[
	FileNameJoin[{ParentDirectory[$assembled], $pacletName}],
	FileNameJoin[{ParentDirectory[$inputDirectory],$pacletName}]
];


(* ::Section:: *)
(*notes*)


(*
Re version numbering:

The code above which builds the .paclet file starts from a PacletInfoTemplate.m
file, and creates a new PacletInfo.m file, using the current date and time as
part of a newly synthesized version number.

One consequence of this is that the static PacletInfo.m file will not be used,
except by developers who install the original source of GitLink, which should be
limited to only people who are developing GitLink.

For this reason, the version number in the static PacletInfo.m file should
always be greater than the version number synthesized here. That way, GitLink
developers can install the original source, and have it preferred over versions
of this paclet installed from the internal paclet server.
*)


(*
To deploy a .paclet file to the internal paclet server:

--
% scp GitLink-x.y.z.paclet username@paclet-int:/mnt/paclets/to-deploy/internal/.

% ssh paclet-int

paclet-int% ls -la /mnt/paclets/to-deploy/internal

paclet-int% cd /PacletProcessing/PacletSystem/Paclet-Int/scripts/

paclet-int% ant pushInternal
--

It's not uncommon for this ant script to take 40 minutes or more to complete.
*)


(*
To install / update from the internal paclet server:

PacletManager`PacletUpdate[#1,"Site"->"http://paclet-int.wolfram.com:8080/PacletServerInternal"]& /@
  {"GitLink", "StashLink"}
*)
