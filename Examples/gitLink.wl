(* ::Package:: *)

(* ::Input:: *)
(*Quit*)


(* ::Subsection::Closed:: *)
(*Init*)


InitializeGitLibrary[] := 
Block[{path},
	path = FindLibrary["gitlink"];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;

		GL`libGitVersion = LibraryFunctionLoad[$GitLibrary, "libGitVersion", {}, {Integer, 1}];
		GL`libGitFeatures = LibraryFunctionLoad[$GitLibrary, "libGitFeatures", LinkObject, LinkObject];

		GL`GitRepoQ = LibraryFunctionLoad[$GitLibrary, "GitRepoQ", {"UTF8String"}, "Boolean"];
		GL`GitRemoteQ = LibraryFunctionLoad[$GitLibrary, "GitRemoteQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitBranchQ = LibraryFunctionLoad[$GitLibrary, "GitBranchQ", {Integer, "UTF8String"}, "Boolean"];

		GL`GitProperties = LibraryFunctionLoad[$GitLibrary, "GitProperties", LinkObject, LinkObject];
		GL`GitStatus = LibraryFunctionLoad[$GitLibrary, "GitStatus", LinkObject, LinkObject];

		GL`GitFetch = LibraryFunctionLoad[$GitLibrary, "GitFetch", {Integer, "UTF8String", "Boolean"}, "UTF8String"];
		GL`GitPush = LibraryFunctionLoad[$GitLibrary, "GitPush", {Integer, "UTF8String", "UTF8String"}, "UTF8String"];

		GL`AssignToManagedRepoInstance = LibraryFunctionLoad[$GitLibrary, "assignToManagedRepoInstance", {"UTF8String", Integer}, "UTF8String"];
		"Initialization complete";
	]
]


(* ::Subsubsection::Closed:: *)
(*utilities*)


assignToManagedRepoInstance[path_String, GitRepo[id_Integer]] :=
	If[GL`AssignToManagedRepoInstance[path, id] === "", $Failed, GitRepo[id]]


cleanRepo[repo: GitRepo[_Integer]] :=
	DeleteFile[ FileNames["*.orig", GitProperties[repo, "WorkingDirectory"], Infinity] ]


(*
handleConflictedNotebook attempts to clean up bad notebook merges.

If there are conflict marks in the body of the Notebook[] expression, it
can't be automatically cleaned up. Return "Uncleanable".

If there are conflict marks outside the body of the Notebook, clear out 
the comment marks and save the cleaned notebook file to a new file. Return
"Cleaned" \[Rule] "new file name".
*)

handleConflictedNotebook[nbfile_String] := 
Module[{lines, begin, end, conflictsequence, state, newfile},
	begin = "(* Beginning of Notebook Content *)";
	end = "(* End of Notebook Content *)";
	conflictsequence = Sequence @@ {"<<<<<<< ", "=======", ">>>>>>> "};

	lines = FindList[nbfile, {begin, end, conflictsequence}];
	state = Switch[lines,
		{begin, end},
			"Clean",
		{__, begin, end} | {begin, end, __} | {__, begin, end, __},
			"Cleanable",
		{___, begin, __, end, ___} | {__},
			"Uncleanable",
		{},
			"Clean(NoCache)",
		_,
			"--UnknownState--"
	];
	If[state === "Cleanable",
		lines = ReadList[nbfile, Record, RecordSeparators -> {"\r\n", "\n", "\r"}, NullRecords -> True];
		lines = Replace[lines, {___, begin, content__, end, ___} :> {content}];
		newfile = FileNameJoin[MapAt["CLEANED-" <> # &, FileNameSplit[nbfile], -1]];
		"Cleaned" -> Export[newfile, ToExpression @ StringJoin[Riffle[lines, "\n"]], "NB"],
		state		
	]
]


(* ::Subsubsection::Closed:: *)
(*Introspection*)


$GitLibraryInformation := 
Association[{
	"Version" -> Replace[GL`libGitVersion[], {a_List :> StringJoin[Riffle[ToString /@ a, "."]], _ -> None}],
	"Features" -> Replace[GL`libGitFeatures[], {a_List :> a, _ -> None}],
	"Location" -> Replace[$GitLibrary, {a_String :> a, _ -> Missing["NotFound"]}],
	"Date" -> Replace[$GitLibrary, {a_String :> FileDate[a], _ -> None}]
}]


(* ::Subsubsection::Closed:: *)
(*Q functions*)


GitRepoQ[path_String] := TrueQ[GL`GitRepoQ[AbsoluteFileName[path]]];


GitRemoteQ[GitRepo[id_Integer], remote_String] := GL`GitRemoteQ[id, remote];


GitBranchQ[GitRepo[id_Integer], branch_String] := GL`GitBranchQ[id, branch];


(* ::Subsubsection::Closed:: *)
(*Query functions*)


GitProperties[GitRepo[id_Integer]] := GL`GitProperties[id];

GitProperties[repo: GitRepo[_Integer], All] := GitProperties[repo];
GitProperties[repo: GitRepo[_Integer], "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitProperties[repo], prop]


GitStatus[GitRepo[id_Integer]] := GL`GitStatus[id];

GitStatus[repo: GitRepo[_Integer], All] := GitStatus[repo];
GitStatus[repo: GitRepo[_Integer], "Properties"] := Keys[GitStatus[repo]];
GitStatus[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitStatus[repo], prop]


(* ::Subsubsection::Closed:: *)
(*Git commands*)


GitOpen[path_String]:=
	With[{abspath = AbsoluteFileName[path]},
		If[GitRepoQ[abspath],
			assignToManagedRepoInstance[abspath, CreateManagedLibraryExpression["gitRepo", GitRepo]],
			$Failed] ];	


errorValueQ[str_String] := (str =!= "success")


Options[GitFetch] = {"Prune" -> False};

GitFetch[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	With[{result = GL`GitFetch[id, remote, TrueQ @ OptionValue["Prune"]]},
		If[errorValueQ[result], Message[MessageName[GitFetch, result], id, remote]; $Failed, result] ]


Options[GitPush] = {};

GitPush[GitRepo[id_Integer], remote_String, branch_String, OptionsPattern[]] :=
	With[{result = GL`GitPush[id, remote, branch]},
		If[errorValueQ[result], Message[MessageName[GitPush, result], id, remote, branch]; $Failed, result] ]


(* ::Subsubsection::Closed:: *)
(*Initialize the library*)


Block[{$LibraryPath = Append[$LibraryPath, "~/bin/"]}, InitializeGitLibrary[]]


(* ::Subsection::Closed:: *)
(*Tests*)


(* ::Input:: *)
(*$GitLibraryInformation*)


(* ::Input:: *)
(*{GitRepoQ["/Users/jfultz/wolfram/fe/Fonts"],GitRepoQ["/Users/jfultz/wolfram/fe"],GitRepoQ["/files/git/fe/Fonts"]}*)


(* ::Input:: *)
(*repo=GitOpen["/Users/jfultz/test_repo"]*)


(* ::Input:: *)
(*GitProperties[repo]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*{GitRemoteQ[repo,"origin"],GitRemoteQ[repo,"foo"]}*)


(* ::Input:: *)
(*{GitBranchQ[repo,"master"],GitBranchQ[repo,"foo"]}*)


(* ::Input:: *)
(*repo2=GitOpen["/Users/jfultz/wolfram/git/Test2"]*)


(* ::Input:: *)
(*GitRemoteQ[repo2,"origin"]*)


(* ::Input:: *)
(*GitProperties[repo2]*)


(* ::Input:: *)
(*GitFetch[repo2,"origin"]*)


(* ::Input:: *)
(*repo = GitOpen["/files/git/fe/Fonts"]*)


(* ::Input:: *)
(*GitRemoteQ[repo, "origin"]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*GitFetch[repo, "origin"]*)


(* ::Subsection::Closed:: *)
(*Palette work*)


viewerRepoList[a_List] := (CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = a);

viewerRepoList[] := CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}, {}]


addRepoToViewer[Dynamic[repo_]] := Replace[
	SystemDialogInput["Directory", WindowTitle -> "Select a directory containing a git repository"],
	a_String :> If[GitRepoQ[a],
		(viewerRepoList[DeleteDuplicates @ Append[viewerRepoList[], a]]; repo = GitOpen[a]),
		(Message[GitOpen::notarepo, a]; repo = None)
	]
]


manageRepoList[] := CreateDocument[ExpressionCell[Defer[CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = #], "Input"]]& @ viewerRepoList[]


viewerToolbar[Dynamic[repo_]] := Grid[{Button[#, Enabled -> False]& /@ {"Fetch", "Pull", "Push", "Branch", "Merge", "Commit", "Reveal", "Help"}}, ItemSize -> Full]


chooseRepositoryMenu[Dynamic[repo_]] := 
	ActionMenu["Repositories",
		Flatten[{
			(# :> (repo = GitOpen[#]))& /@ viewerRepoList[],
			If[viewerRepoList[] === {}, {}, Delimiter],
			"Browse\[Ellipsis]" :> addRepoToViewer[Dynamic[repo]],
			Delimiter,
			"Manage Repository List\[Ellipsis]" :> manageRepoList[]
		}],
		Method->"Queued"
	]


viewerSummaryColumn[Dynamic[repo_]] := chooseRepositoryMenu[Dynamic[repo]] /; repo === None

viewerSummaryColumn[Dynamic[repo_]] :=
	Column[Flatten[{
		chooseRepositoryMenu[Dynamic[repo]],
		Grid[{{
			Style[GitProperties[repo, "WorkingDirectory"], Larger],
			Button[
				Dynamic[RawBoxes @ FEPrivate`FrontEndResource["FEBitmaps", "CircleXIcon"]],
				repo = None,
				Appearance -> None]
		}}],
		Grid[Join[
				
				{{Style["Properties:", Bold], SpanFromLeft}},
				Replace[
					List @@@ Normal[GitProperties[repo]],
					{prop: ("LocalBranches" | "RemoteBranches"), val_List} :>
						Sequence @@ {{Style["\n" <> prop <> ":", Bold], SpanFromLeft}, {branchHierarchy[Dynamic[repo], val], SpanFromLeft}},
					{1}
				]
			],
			Alignment -> Left,
			ItemSize -> Full
		]
	}], Spacings -> 2, Dividers -> Center, FrameStyle -> LightGray, ItemSize -> Full]


branchicon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];

branchopenericon = Dynamic[RawBoxes[FEPrivate`ImportImage[FrontEnd`ToFileName[{"Popups", "CodeCompletion"}, "MenuItemDirectoryTiny.png"]]]];

formatBranch[Dynamic[repo_], {prefix___, name_}] := Row[{branchicon, " ", Tooltip[name, FileNameJoin[{prefix, name}]]}]

formatBranchOpener[Dynamic[repo_], {above___, here_}, allbranches_] := 
	OpenerView[{
		Row[{branchopenericon, " ", here}],
		Column[
			Module[{branches, subbranches},
				branches = Cases[allbranches, {above, here, name_} :> {above, here, name}];
				subbranches = Cases[allbranches, {above, here, next_, __} :> {above, here, next}];
				Join[
					formatBranch[Dynamic[repo], #]& /@ branches,
					formatBranchOpener[Dynamic[repo], #, allbranches]& /@ DeleteDuplicates[subbranches]
				]
			],
			BaselinePosition -> {1,1},
			ItemSize -> Full
		]
	}]

branchHierarchy[Dynamic[repo_], prop_String] := branchHierarchy[Dynamic[repo], GitProperties[repo, prop]]

branchHierarchy[Dynamic[repo_], branchList: {___String}] := 
Module[{allbranches = StringSplit[branchList, "/"], branches, subbranches},
	branches = Cases[allbranches, {_}];
	subbranches = Cases[allbranches, {base_, __} :> {base}];
	Column[
		Join[
			formatBranch[Dynamic[repo], #]& /@ branches,
			formatBranchOpener[Dynamic[repo], #, allbranches]& /@ DeleteDuplicates[subbranches]
		],
		BaselinePosition -> {1,1},
		ItemSize -> Full
	]
]


viewerDetailView[Dynamic[repo_]] :=
	If[repo === None,
		Style["No repository selected", LightGray],
		Grid[Join[
				{{Style["Status:", Bold], SpanFromLeft}},
				List @@@ Normal[GitStatus[repo]]
			],
			Alignment -> Left
		]
	]


RepoViewer[] := 
DynamicModule[{repo=None},
	Dynamic[
		Grid[{
			{
				Pane[viewerToolbar[Dynamic[repo]], ImageMargins -> 10],
				SpanFromLeft
			},
			{
				Pane[viewerSummaryColumn[Dynamic[repo]], ImageMargins -> 10],
				Item[Pane[viewerDetailView[Dynamic[repo]], ImageMargins -> 10], Background -> White, ItemSize -> Fit]
			}},
			Alignment -> {Left, Top},
			Background -> GrayLevel[0.95],
			Dividers -> {Center, Center},
			FrameStyle -> LightGray
		],
		SynchronousUpdating -> False
	]
]


ShowRepoViewer[] := 
CreatePalette[
	RepoViewer[],
	Saveable -> False,
	WindowSize -> {650,500},
	WindowElements -> {"StatusArea", "HorizontalScrollBar", "VerticalScrollBar"},
	WindowFrameElements -> {"CloseBox", "ZoomBox", "MinimizeBox", "ResizeArea"},
	WindowTitle -> "Git"
]


(* ::Input:: *)
(*NotebookClose[nb];*)
(*nb = ShowRepoViewer[];*)


(* ::Subsection::Closed:: *)
(*WRI*)


WRIGitConfigured[repoObj_] := True (* more to come *)


pullRequestBranchCheck[repoObj_GitObject, branch_String, remote_String] :=
	GitBranchQ[repoObj, branch, remote] &&
		If[GitBranchQ[repoObj, branch],
			GitCommitParentQ[GitCommitObject[repoObj, branch], GitCommitObject[repoObj, branch, remote]], True];


readyToMergePullRequest[repoObj_GitObject, source_String, remote_String] :=
	Module[{},
		return=GitRemoteQ[repoObj, remote] && GitFetch[repoObj, remote, "Prune"->True];
		return=return&&pullRequestBranchCheck[repoObj, source, remote];
		return
	]


getWRIRepo[repo_String, remote_String] := Module[{repoObj},
	repoObj = GitOpen[repo];
	If[repoObj =!= $Failed && GitRemoteQ[repoObj, remote] && WRIGitConfigured[repoObj],
		repoObj,
		(*Quiet[GitClose[repoObj]];*) $Failed]];


rebasePullRequest[repoObj_GitObject, branch_String,remote_String, andSquash_]:=
	Module[{},
	]


MergePullRequest[repo_String, branch_String, opts_] :=
	Catch[Module[{repoObj, remote="Remote"/.opts/."Remote"->"origin", squash="Squash"/.opts/."Squash"->True},
		If[!GitRepoQ[repo], Message[MergePullRequest::repoNotFound]; Throw[$Failed]];
		If[!getWRIRepo[repo]===$Failed, Message[MergePullRequest::badRepo]; Throw[$Failed]];
		If[!readyToMergePullRequest[repoObj,branch,remote], Message[MergePullRequest::badBranch]; Throw[$Failed]];
		If[!rebasePullRequest[repoObj,branch,remote,squash], Message[MergePullRequest::cantRebase]; Throw[$Failed]];
		If[GitBranchQ[repoObj,branch],GitDeleteBranch[repoObj,branch]];
		GitCommitObject[repoObj,"master"]
	]]




repo
