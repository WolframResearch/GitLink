(* ::Package:: *)

(* ::Input:: *)
(*Quit*)


(* ::Subsection:: *)
(*Init*)


(* ::Subsubsection::Closed:: *)
(*InitializeGitLibrary*)


InitializeGitLibrary[] := 
Block[{path},
	path = FindLibrary["gitlink"];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;
		$GitCredentialsFile = FileNameJoin[{$HomeDirectory, ".ssh", "id_rsa"}];

		GL`libGitVersion = LibraryFunctionLoad[$GitLibrary, "libGitVersion", {}, {Integer, 1}];
		GL`libGitFeatures = LibraryFunctionLoad[$GitLibrary, "libGitFeatures", LinkObject, LinkObject];

		GL`GitRepoQ = LibraryFunctionLoad[$GitLibrary, "GitRepoQ", {"UTF8String"}, "Boolean"];
		GL`GitRemoteQ = LibraryFunctionLoad[$GitLibrary, "GitRemoteQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitBranchQ = LibraryFunctionLoad[$GitLibrary, "GitBranchQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitCommitQ = LibraryFunctionLoad[$GitLibrary, "GitCommitQ", LinkObject, LinkObject];

		GL`GitProperties = LibraryFunctionLoad[$GitLibrary, "GitProperties", LinkObject, LinkObject];
		GL`GitCommitProperties = LibraryFunctionLoad[$GitLibrary, "GitCommitProperties", LinkObject, LinkObject];
		GL`GitStatus = LibraryFunctionLoad[$GitLibrary, "GitStatus", LinkObject, LinkObject];
		GL`GitSHA = LibraryFunctionLoad[$GitLibrary, "GitSHA", LinkObject, LinkObject];
		GL`GitRange = LibraryFunctionLoad[$GitLibrary, "GitRange", LinkObject, LinkObject];

		GL`GitFetch = LibraryFunctionLoad[$GitLibrary, "GitFetch", {Integer, "UTF8String", "UTF8String", "Boolean"}, "UTF8String"];
		GL`GitPush = LibraryFunctionLoad[$GitLibrary, "GitPush", {Integer, "UTF8String", "UTF8String"}, "UTF8String"];
		GL`GitCherryPick = LibraryFunctionLoad[$GitLibrary, "GitCherryPick", LinkObject, LinkObject];
		GL`GitCherryPickCommit = LibraryFunctionLoad[$GitLibrary, "GitCherryPickCommit", LinkObject, LinkObject];

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


GitRepoQ[path_] := StringQ[path] && TrueQ[GL`GitRepoQ[AbsoluteFileName[path]]];


GitRemoteQ[GitRepo[id_Integer], remote_] := StringQ[remote] && TrueQ[GL`GitRemoteQ[id, remote]];


GitBranchQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitBranchQ[id, branch]];


GitCommitQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitCommitQ[id, branch]];


(* ::Subsubsection::Closed:: *)
(*Query functions*)


GitProperties[GitRepo[id_Integer]] := GL`GitProperties[id];

GitProperties[repo: GitRepo[_Integer], All] := GitProperties[repo];
GitProperties[repo: GitRepo[_Integer], "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitProperties[repo], prop]


GitCommitProperties[GitRepo[id_Integer], commit_String] := GL`GitCommitProperties[id, commit];

GitCommitProperties[repo: GitRepo[_Integer], commit_String, All] := GitCommitProperties[repo, commit];
GitCommitProperties[repo: GitRepo[_Integer], commit_String, "Properties"] := Keys[GitCommitProperties[repo, commit]];
GitCommitProperties[repo: GitRepo[_Integer], commit_String, prop: (_String | {___String})] := Lookup[GitCommitProperties[repo, commit], prop]


GitStatus[GitRepo[id_Integer]] := GL`GitStatus[id];

GitStatus[repo: GitRepo[_Integer], All] := GitStatus[repo];
GitStatus[repo: GitRepo[_Integer], "Properties"] := Keys[GitStatus[repo]];
GitStatus[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitStatus[repo], prop]


GitSHA[GitRepo[id_Integer], spec_] := GL`GitSHA[id, spec];


GitRange[GitRepo[id_Integer], spec: ((_String | HoldPattern[Not[_String]])..)] := GL`GitRange[id, spec];


(* ::Subsubsection::Closed:: *)
(*Git commands*)


GitOpen[path_String]:=
	With[{abspath = AbsoluteFileName[path]},
		If[StringQ[abspath] && GitRepoQ[abspath],
			assignToManagedRepoInstance[abspath, CreateManagedLibraryExpression["gitRepo", GitRepo]],
			$Failed] ];


errorValueQ[str_String] := (str =!= "success")


Options[GitFetch] = {"Prune" -> False};

GitFetch[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	With[{result = GL`GitFetch[id, remote, $GitCredentialsFile, TrueQ @ OptionValue["Prune"]]},
		If[errorValueQ[result], Message[MessageName[GitFetch, result], id, remote]; $Failed, result] ]


Options[GitPush] = {};

GitPush[GitRepo[id_Integer], remote_String, branch_String, OptionsPattern[]] :=
	With[{result = GL`GitPush[id, remote, branch]},
		If[errorValueQ[result], Message[MessageName[GitPush, result], id, remote, branch]; $Failed, result] ]


Options[GitCherryPick] = {};

(* flaky...returns true false with a changed index...decide what to do here *)
GitCherryPick[GitRepo[id_Integer], commit_String, branch_String, OptionsPattern[]] :=
	GL`GitCherryPick[id, commit];

(* much better...returns the SHA of the new commit or $Failed *)
GitCherryPick[GitRepo[id_Integer], fromCommit_String, toCommit_String, reference_String] :=
	GL`GitCherryPickCommit[id, fromCommit, toCommit, reference];


(* ::Subsubsection::Closed:: *)
(*Typeset rules*)


giticon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];


GitRepo /: MakeBoxes[GitRepo[id_Integer], fmt_] :=
	With[{
		icon = ToBoxes[giticon],
		name = Replace[GitProperties[GitRepo[id], "WorkingDirectory"], {a_String :> ToBoxes[a, fmt], _ :> MakeBoxes[id, fmt]}],
		tooltip = ToString[GitRepo[id], InputForm]},

		TemplateBox[{MakeBoxes[id, fmt]}, "GitRepo",
				DisplayFunction -> (
					TooltipBox[PanelBox[GridBox[{{icon, name}}, BaselinePosition -> {1,2}],
						FrameMargins -> 5, BaselinePosition -> Baseline], tooltip]&)]
	]


(* ::Subsubsection::Closed:: *)
(*Initialize the library*)


Block[{$LibraryPath = Append[$LibraryPath, "~/bin/"]}, InitializeGitLibrary[]]


(* ::Subsection:: *)
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
(*GitRange[repo,"feature/conflict"]*)


(* ::Input:: *)
(*GitCommitProperties[repo,"master"]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*GitSHA[repo,#]&/@{"master","master@{1}","ce36c95",Not["master"],"bogus","1234abcd",foo[bar],1/3}*)


(* ::Input:: *)
(*GitCommitQ[repo,#]&/@{"master","master@{1}","ce36c95",Not["master"],"bogus","1234abcd",foo[bar],1/3}*)


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


(* ::Subsubsection:: *)
(*Cherry-pick tests*)


(* ::Input:: *)
(*ferepo=GitOpen["~/wolfram/fe/FrontEnd"]*)


(* ::Input:: *)
(*GitSHA[ferepo,"origin/bugfix/266779"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","WOLFRAM_STASH_REBASE_HEAD"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","refs/heads/WOLFRAM_STASH_REBASE_HEAD"]*)


(* ::Subsection::Closed:: *)
(*Palette work*)


(*
Ultimate goals:

1. Merging pull requests in the right way (via cherry picking and rebase) rather than 
via merge commits (which (a) leave a tangled history, and (b) use a horrible message for the
merge commit).

2. Automatic handling of / knowledge of WRI-specific collections of repos. Eg: the collection
of repos that are needed to build the front end. You shouldn't need to go to a twiki to find
that out.

3. Automatic merging / building of an executable from a manifest file which lists multiple
branches for each repo, with some common sense about merge failures. (Eg, when merging
branches a, b, and c into repo x, first merge a, then b, then c. If there were merge failures
for any particular branch, back out that branch's merge and continue with the next one.)
*)


viewerRepoList[a_List] := (CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = a);

viewerRepoList[] := CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}, {}]


addRepoToViewer[Dynamic[repo_]] := Replace[
	SystemDialogInput["Directory", WindowTitle -> "Select a directory containing a git repository"],
	a_String :> If[GitRepoQ[a],
		(viewerRepoList[DeleteDuplicates @ Append[viewerRepoList[], AbsoluteFileName[a]]]; repo = GitOpen[a]),
		(Message[GitOpen::notarepo, a]; repo = None)
	]
]


manageRepoList[] := CreateDocument[ExpressionCell[Defer[CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = #], "Input"]]& @ viewerRepoList[]


viewerToolbar[Dynamic[repo_], Dynamic[branch_]] :=
	Grid[{Button[#, Enabled -> False]& /@ {"Fetch", "Pull", "Push", "Branch", "Merge", "Commit", "Reveal", "Help"}}, ItemSize -> Full]


chooseRepositoryMenu[Dynamic[repo_]] := 
	ActionMenu["Repositories",
		Flatten[{
			(Row[{FileNameTake[#], Style[" \[LongDash] " <> FileNameDrop[#], FontColor -> Gray]}] :> (repo = GitOpen[#]))& /@ viewerRepoList[],
			If[viewerRepoList[] === {}, {}, Delimiter],
			"Browse\[Ellipsis]" :> addRepoToViewer[Dynamic[repo]],
			Delimiter,
			"Manage Repository List\[Ellipsis]" :> manageRepoList[]
		}],
		Method->"Queued"
	]


viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] := chooseRepositoryMenu[Dynamic[repo]] /; repo === None

viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] :=
	Column[Flatten[{
		chooseRepositoryMenu[Dynamic[repo]],
		Grid[{{
			Style[GitProperties[repo, "WorkingDirectory"], Larger],
			Button[
				Dynamic[RawBoxes @ FEPrivate`FrontEndResource["FEBitmaps", "CircleXIcon"]],
				repo = None,
				Appearance -> None]
		}}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[GitProperties[repo, "LocalBranches"], { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[GitProperties[repo, "RemoteBranches"], { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],

		Grid[Join[
				{{Style["Other Properties:", Bold], SpanFromLeft}},
				DeleteCases[List @@@ Normal[GitProperties[repo]], {("LocalBranches" | "RemoteBranches"), _}]
			],
			Alignment -> Left
		]
	}], Spacings -> 2, Dividers -> Center, FrameStyle -> LightGray, ItemSize -> Full]


branchicon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];

branchopenericon = Dynamic[RawBoxes[FEPrivate`ImportImage[FrontEnd`ToFileName[{"Popups", "CodeCompletion"}, "MenuItemDirectoryTiny.png"]]]];

formatBranch[Dynamic[repo_], Dynamic[branch_], {prefix___, name_}] := 
With[{branchname = FileNameJoin[{prefix, name}]},
	Button[
		Row[{branchicon, " ", Tooltip[name, branchname]}, BaseStyle -> Dynamic[If[CurrentValue["MouseOver"] || branch === branchname, Bold, {}]]],
		branch = branchname,
		Appearance -> None,
		BaseStyle -> {},
		DefaultBaseStyle -> {}
	]
]

formatBranchOpener[Dynamic[repo_], Dynamic[branch_], {above___, here_}, allbranches_] := 
	OpenerView[{
		Row[{branchopenericon, " ", here}],
		Column[
			Module[{branches, subbranches},
				branches = Cases[allbranches, {above, here, name_} :> {above, here, name}];
				subbranches = Cases[allbranches, {above, here, next_, __} :> {above, here, next}];
				Join[
					formatBranch[Dynamic[repo], Dynamic[branch], #]& /@ Union[branches],
					formatBranchOpener[Dynamic[repo], Dynamic[branch], #, allbranches]& /@ Union[subbranches]
				]
			],
			BaselinePosition -> {1,1},
			ItemSize -> Full
		]
	}]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], prop_String] := branchHierarchy[Dynamic[repo], Dynamic[branch], GitProperties[repo, prop]]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], branchList: {___String}] := 
Module[{allbranches = StringSplit[branchList, "/"], branches, subbranches},
	branches = Cases[allbranches, {_}];
	subbranches = Cases[allbranches, {base_, __} :> {base}];
	Column[
		Join[
			formatBranch[Dynamic[repo], Dynamic[branch], #]& /@ Union[branches],
			formatBranchOpener[Dynamic[repo], Dynamic[branch], #, allbranches]& /@ Union[subbranches]
		],
		BaselinePosition -> {1,1},
		ItemSize -> Full
	]
]


viewerDetailView[Dynamic[repo_], Dynamic[branch_], Dynamic[tab_]] :=
	If[repo === None,
		Style["No repository selected", LightGray],
		TabView[
			{
				{"Status", "Status" -> repoStatusGrid[repo]},
				{"Branch", branch -> branchHistoryGrid[repo, branch, GitRange[repo, branch, Not["origin/master"]]]}
			},
		Dynamic[tab],
		ImageSize -> Scaled[1]]
	]


repoStatusGrid[repo_] := 
Grid[
	Join[
		{{Style["Status:", Bold], SpanFromLeft}},
		List @@@ Normal[GitStatus[repo]]
	],
	Alignment -> Left
]


branchHistoryGrid[repo_, branch_, commits: {__}] :=
Grid[
	{
		Tooltip[DateString[#AuthorTime, "DateShort"], DateString[#AuthorTime, "DateTime"]],
		Tooltip[#AuthorName, #AuthorEmail],
		If[#Summary === #Message, #Summary, Tooltip[#Summary, #Message]],
		Tooltip[StringTake[#SHA, 8], Dataset[#]]
	}& /@ (GitCommitProperties[repo, #]& /@ commits),
	Alignment -> Left,
	BaseStyle -> {"TextStyling", LinebreakAdjustments -> {1., 10, 1, 0, 1}},
	(*Spacings \[Rule] {1,1},*)
	Dividers -> {Center, Center},
	FrameStyle -> LightGray
]

branchHistoryGrid[repo_, branch_, commits: {}] := Row[{"No commits found in ", Defer[GitRange[repo, branch, Not["origin/master"]]]}]


RepoViewer[] := 
DynamicModule[{repo = None, branch = "origin/HEAD", tab = "Status"},
	Dynamic[
		Grid[{
			{
				Pane[viewerToolbar[Dynamic[repo], Dynamic[branch]], ImageMargins -> 10],
				SpanFromLeft
			},
			{
				Pane[viewerSummaryColumn[Dynamic[repo], Dynamic[branch]], ImageMargins -> 10, ImageSize -> {{250},{Automatic}}],
				Dynamic[
					Item[Pane[viewerDetailView[Dynamic[repo], Dynamic[branch], Dynamic[tab]], ImageMargins -> 10], Background -> White, ItemSize -> Fit],
					TrackedSymbols :> {repo, branch}
				]
			}},
			Alignment -> {Left, Top},
			Background -> GrayLevel[0.95],
			Dividers -> {Center, Center},
			FrameStyle -> LightGray
		],
		SynchronousUpdating -> False,
		TrackedSymbols :> {repo}
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


(* ::Subsection:: *)
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


