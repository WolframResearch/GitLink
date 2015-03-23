(* ::Package:: *)

(* ::Section:: *)
(*Implementation*)


(* ::Subsection::Closed:: *)
(*Package header*)


BeginPackage["GitLink`"];


$GitLibraryPath;
$GitLibraryInformation;
InitializeGitLibrary;

GitRepoQ;
GitRemoteQ;
GitBranchQ;
GitCommitQ;
GitProperties;
GitStatus;
GitSHA;
GitRange;
GitSignature;
GitType;
ToGitObject;

GitRepo;
GitRepos;
GitObject;
GitOpen;
GitClone;
GitInit;
GitFetch;
GitCommit;
GitPush;
GitCherryPick;
GitMerge;
GitPull;
GitCreateBranch;
GitDeleteBranch;
GitMoveBranch;
GitUpstreamBranch;
GitSetUpstreamBranch;
GitAddRemote;
GitDeleteRemote;
GitCheckoutReference;

GitExpandTree;
GitWriteTree;
GitReadBlob;
GitWriteBlob;

GitRepoList;
ManageGitRepoList;

ShowRepoViewer;


Begin["`Private`"];


(* ::Subsection::Closed:: *)
(*InitializeGitLibrary*)


$EvaluationFileName = Replace[$InputFileName, "" :> NotebookFileName[EvaluationNotebook[]]]


$GitLibraryPath := {}


InitializeGitLibrary[] := 
Block[{path, $LibraryPath = Join[$GitLibraryPath, $LibraryPath]},
	path = FindLibrary["gitLink"];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;
		$GitCredentialsFile = SelectFirst[FileNameJoin[{$HomeDirectory, ".ssh", #}] & /@ {"id_rsa", "id_dsa"}, FileExistsQ, FileNameJoin[{$HomeDirectory, ".ssh", "id_rsa"}]];

		GL`libGitVersion = LibraryFunctionLoad[$GitLibrary, "libGitVersion", {}, {Integer, 1}];
		GL`libGitFeatures = LibraryFunctionLoad[$GitLibrary, "libGitFeatures", LinkObject, LinkObject];

		GL`GitRepoQ = LibraryFunctionLoad[$GitLibrary, "GitRepoQ", LinkObject, LinkObject];
		GL`GitRemoteQ = LibraryFunctionLoad[$GitLibrary, "GitRemoteQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitBranchQ = LibraryFunctionLoad[$GitLibrary, "GitBranchQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitCommitQ = LibraryFunctionLoad[$GitLibrary, "GitCommitQ", LinkObject, LinkObject];

		GL`GitProperties = LibraryFunctionLoad[$GitLibrary, "GitProperties", LinkObject, LinkObject];
		GL`GitCommitProperties = LibraryFunctionLoad[$GitLibrary, "GitCommitProperties", LinkObject, LinkObject];
		GL`GitStatus = LibraryFunctionLoad[$GitLibrary, "GitStatus", LinkObject, LinkObject];
		GL`GitSHA = LibraryFunctionLoad[$GitLibrary, "GitSHA", LinkObject, LinkObject];
		GL`GitRange = LibraryFunctionLoad[$GitLibrary, "GitRange", LinkObject, LinkObject];
		GL`GitSignature = LibraryFunctionLoad[$GitLibrary, "GitSignature", LinkObject, LinkObject];
		GL`GitType = LibraryFunctionLoad[$GitLibrary, "GitType", LinkObject, LinkObject];
		GL`ToGitObject = LibraryFunctionLoad[$GitLibrary, "ToGitObject", LinkObject, LinkObject];

		GL`GitClone = LibraryFunctionLoad[$GitLibrary, "GitClone", LinkObject, LinkObject];
		GL`GitInit = LibraryFunctionLoad[$GitLibrary, "GitInit", LinkObject, LinkObject];
		GL`GitFetch = LibraryFunctionLoad[$GitLibrary, "GitFetch", LinkObject, LinkObject];
		GL`GitCommit = LibraryFunctionLoad[$GitLibrary, "GitCommit", LinkObject, LinkObject];
		GL`GitPush = LibraryFunctionLoad[$GitLibrary, "GitPush", LinkObject, LinkObject];
		GL`GitCherryPick = LibraryFunctionLoad[$GitLibrary, "GitCherryPick", LinkObject, LinkObject];
		GL`GitMerge = LibraryFunctionLoad[$GitLibrary, "GitMerge", LinkObject, LinkObject];
		GL`GitCherryPickCommit = LibraryFunctionLoad[$GitLibrary, "GitCherryPickCommit", LinkObject, LinkObject];
		GL`GitCreateBranch = LibraryFunctionLoad[$GitLibrary, "GitCreateBranch", LinkObject, LinkObject];
		GL`GitDeleteBranch = LibraryFunctionLoad[$GitLibrary, "GitDeleteBranch", LinkObject, LinkObject];
		GL`GitMoveBranch = LibraryFunctionLoad[$GitLibrary, "GitMoveBranch", LinkObject, LinkObject];
		GL`GitUpstreamBranch = LibraryFunctionLoad[$GitLibrary, "GitUpstreamBranch", LinkObject, LinkObject];
		GL`GitSetUpstreamBranch = LibraryFunctionLoad[$GitLibrary, "GitSetUpstreamBranch", LinkObject, LinkObject];
		GL`GitAddRemote = LibraryFunctionLoad[$GitLibrary, "GitAddRemote", LinkObject, LinkObject];
		GL`GitDeleteRemote = LibraryFunctionLoad[$GitLibrary, "GitDeleteRemote", LinkObject, LinkObject];
		GL`GitSetHead = LibraryFunctionLoad[$GitLibrary, "GitSetHead", LinkObject, LinkObject];
		GL`GitCheckoutHead = LibraryFunctionLoad[$GitLibrary, "GitCheckoutHead", LinkObject, LinkObject];
		GL`GitCheckoutReference = LibraryFunctionLoad[$GitLibrary, "GitCheckoutReference", LinkObject, LinkObject];

		GL`GitExpandTree = LibraryFunctionLoad[$GitLibrary, "GitExpandTree", LinkObject, LinkObject];
		GL`GitWriteTree = LibraryFunctionLoad[$GitLibrary, "GitWriteTree", LinkObject, LinkObject];
		GL`GitDiffTrees = LibraryFunctionLoad[$GitLibrary, "GitDiffTrees", LinkObject, LinkObject];
		GL`GitIndexTree = LibraryFunctionLoad[$GitLibrary, "GitIndexTree", LinkObject, LinkObject];
		GL`GitReadBlob = LibraryFunctionLoad[$GitLibrary, "GitReadBlob", LinkObject, LinkObject];
		GL`GitWriteBlob = LibraryFunctionLoad[$GitLibrary, "GitWriteBlob", LinkObject, LinkObject];

		GL`AssignToManagedRepoInstance = LibraryFunctionLoad[$GitLibrary, "assignToManagedRepoInstance", LinkObject, LinkObject];
		"Initialization complete";
	]
]


(* ::Subsection::Closed:: *)
(*Utilities*)


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


isHeadBranch[repo_GitRepo, ref_String] := 
	With[{headBranch = GitProperties[repo, "HeadBranch"]},
		ref === "HEAD" && GitBranchQ[repo, headBranch] ||
		ref === headBranch
	]


(* create tmpBranch at result, check it out, move dest, set HEAD to dest, and clean up *)
relocateHeadBranchIfItExists[repo_GitRepo, result_GitObject, throwTag_] :=
	Module[{headBranch = GitProperties[repo, "HeadBranch"]},
		If[GitBranchQ[repo, headBranch] ,
			If[Quiet@GitCheckoutReference[repo, result] === $Failed,
				Message[throwTag::checkoutconflict]; Throw[$Failed, throwTag]];
			GitMoveBranch[headBranch, result];
			GL`GitSetHead[repo[[1]], headBranch];
		]
	];


(* ::Subsection::Closed:: *)
(*Introspection*)


$GitLibraryInformation := 
Association[{
	"Version" -> Replace[GL`libGitVersion[], {a_List :> StringJoin[Riffle[ToString /@ a, "."]], _ -> None}],
	"Features" -> Replace[GL`libGitFeatures[], {a_List :> a, _ -> None}],
	"Location" -> Replace[$GitLibrary, {a_String :> a, _ -> Missing["NotFound"]}],
	"Date" -> Replace[$GitLibrary, {a_String :> FileDate[a], _ -> None}]
}]


(* ::Subsection::Closed:: *)
(*Q functions*)


GitRepoQ[path_] := With[{abspath = AbsoluteFileName[path]}, StringQ[abspath] && TrueQ[GL`GitRepoQ[abspath]]];


GitRemoteQ[GitRepo[id_Integer], remote_] := StringQ[remote] && TrueQ[GL`GitRemoteQ[id, remote]];
GitRemoteQ[__] := $Failed


GitBranchQ[repo:GitRepo[_Integer], "HEAD"] := GitBranchQ[repo, GitProperties[repo]["HeadBranch"]];
GitBranchQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitBranchQ[id, branch]];
GitBranchQ[__] := $Failed


GitCommitQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitCommitQ[id, branch]];
GitCommitQ[GitObject[sha_String, GitRepo[id_Integer]]] := TrueQ[GL`GitCommitQ[id, sha]];
GitCommitQ[__] := $Failed


(* ::Subsection::Closed:: *)
(*Query functions*)


GitProperties[GitRepo[id_Integer]] := GL`GitProperties[id];

GitProperties[repo: GitRepo[_Integer], All] := GitProperties[repo];
GitProperties[repo: GitRepo[_Integer], "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo: GitRepo[_Integer], "Panel"] := propertiesPanel[repo];
GitProperties[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitProperties[repo], prop];

GitProperties[GitObject[sha_String, GitRepo[id_Integer]]?(GitType[#]==="Commit"&)] := GL`GitCommitProperties[id, sha];
GitProperties[GitObject[sha_String, GitRepo[id_Integer]]] := <||>; (* fallthrough for unimplemented properties *)

GitProperties[obj_GitObject, All] := GitProperties[obj];
GitProperties[obj_GitObject, "Properties"] := Keys[GitProperties[obj]];
GitProperties[obj_GitObject, "Panel"] := propertiesPanel[obj];
GitProperties[obj_GitObject, prop: (_String | {___String})] := Lookup[GitProperties[obj], prop];


Options[GitStatus] = {"DetectRenames" -> False};

GitStatus[GitRepo[id_Integer], opts:OptionsPattern[]] := GL`GitStatus[id, OptionValue["DetectRenames"]];

GitStatus[repo: GitRepo[_Integer], All, opts:OptionsPattern[]] := GitStatus[repo];
GitStatus[repo: GitRepo[_Integer], "Properties", opts:OptionsPattern[]] := Keys[GitStatus[repo, opts]];
GitStatus[repo: GitRepo[_Integer], prop: (_String | {___String}), opts:OptionsPattern[]] := Lookup[GitStatus[repo, opts], prop];


GitSHA[GitRepo[id_Integer], spec_] := GL`GitSHA[id, spec];
GitSHA[GitObject[sha_, _GitRepo]] := sha;


$GitRangeMemoizations = <||>;
$GitRangeLengthMemoizations = <||>;
memoizeRangeSpec[var_, func_, spec_List] :=
	Module[{sortedSpec = Sort[spec]},
		If[MatchQ[var[sortedSpec], _Missing], var[sortedSpec] = func @@ sortedSpec, var[sortedSpec]]
	];
SetAttributes[memoizeRangeSpec, HoldAll];
specToGitObject[ref_String, repo_GitRepo] := ToGitObject[ref, repo];
specToGitObject[Not[ref_String], repo_GitRepo] := Not[ToGitObject[ref, repo]];
specToGitObject[arg_, repo_GitRepo] := arg;

GitRange[GitRepo[id_Integer], spec: ((_GitObject | HoldPattern[Not[_GitObject]])..)] := 
	memoizeRangeSpec[$GitRangeMemoizations, GL`GitRange[id, False, ##]&, {spec}];
GitRangeLength[GitRepo[id_Integer], spec: ((_GitObject | HoldPattern[Not[_GitObject]])..)] :=
	memoizeRangeSpec[$GitRangeLengthMemoizations, GL`GitRange[id, True, ##]&, {spec}];

GitRange[repo_GitRepo, spec: ((_String|_GitObject | HoldPattern[Not[_String|_GitObject]])..)] :=
	GitRange[repo, Sequence @@ (specToGitObject[#, repo]& /@ {spec})];
GitRangeLength[repo_GitRepo, spec: ((_String|_GitObject | HoldPattern[Not[_String|_GitObject]])..)] :=
	GitRangeLength[repo, Sequence @@ (specToGitObject[#, repo]& /@ {spec})];


GitSignature[] := GL`GitSignature[];
GitSignature[GitRepo[id_Integer]] := GL`GitSignature[id];
GitSignature[GitRepo[id_Integer], ref_String] := GL`GitSignature[id, ref];


GitType[GitObject[sha_String, GitRepo[id_]]] := GL`GitType[id, sha];
GitType[_] := None;


ToGitObject[ref_String, GitRepo[id_]] := GL`ToGitObject[id, ref];
ToGitObject[obj:GitObject[_String, GitRepo[id_]], GitRepo[id_]] := obj;
ToGitObject[obj_GitObject, repo_GitRepo] := (Message[ToGitObject::mismatchedgitobj, obj, repo]; obj);
ToGitObject[__] := $Failed;


$GitRepos = {};
GitRepos[] := $GitRepos;
GitRepos[abspath:(_String|_StringExpression)] := Select[$GitRepos,
	StringMatchQ[First[#], abspath,
		IgnoreCase -> ($OperatingSystem === "Windows" || $OperatingSystem === "MacOSX")]&
];


(* ::Subsection::Closed:: *)
(*Git commands*)


GitOpen[path_String]:=
	Module[{abspath = AbsoluteFileName[path], repos, repo},
		repos = GitRepos[abspath];
		Which[
			MatchQ[repos, {(_ -> _GitRepo)..}], repos[[1,2]],
			StringQ[abspath] && GitRepoQ[abspath],
				repo = assignToManagedRepoInstance[abspath, CreateManagedLibraryExpression["gitRepo", GitRepo]];
				PrependTo[$GitRepos, abspath -> repo];
				repo,
			True, $Failed]
	];


errorValueQ[str_String] := (str =!= "success")


Options[GitClone] = {"Bare" -> False, "ProgressMonitor" -> None};

GitClone[uri_String, opts:OptionsPattern[]] :=
	Module[{dirName = Last[StringSplit[uri, "/"|"\\"]]},
		dirName = StringReplace[dirName, c__~~".git"~~EndOfString :> c];
		GitClone[uri, FileNameJoin[{Directory[], dirName}], opts]
	];
GitClone[uri_String, localPath_String, OptionsPattern[]] :=
	Module[{result, dirExistedQ = DirectoryQ[localPath]},
		(* GL`GitClone doesn't create the directories with the
			right permissions.  GitInit does.  So init, then clean it out. *)
		GitInit[localPath];
		DeleteDirectory[FileNameJoin[{localPath, ".git"}],DeleteContents->True];
		result = GL`GitClone[uri, localPath, $GitCredentialsFile,
			TrueQ @ OptionValue["Bare"],
			OptionValue["ProgressMonitor"]
		];
		(* If the clone failed and the directory didn't exist before, delete it. *)
		If[result === $Failed && Not[dirExistedQ] && DirectoryQ[localPath],
			DeleteDirectory[localPath, DeleteContents -> True]
		];
		result
	]


Options[GitInit] = {"Bare" -> False, "Description" -> None, "Overwrite" -> False, "WorkingDirectory" -> None};

GitInit[path_String, opts:OptionsPattern[]] := Module[{result},
	result = GL`GitInit[path, OptionValue["WorkingDirectory"],
		OptionValue["Bare"], OptionValue["Description"], OptionValue["Overwrite"]];
	If[MatchQ[result, _GitRepo], PrependTo[$GitRepos, AbsoluteFileName[path] -> result]];
	result
]



Options[GitFetch] = {"Prune" -> False};

GitFetch[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	GL`GitFetch[id, remote, $GitCredentialsFile, TrueQ @ OptionValue["Prune"]];


Options[GitCommit] = {"AuthorSignature"->Automatic, "CommitterSignature"->Automatic};

GitCommit[repo:GitRepo[_Integer], log_String, tree_:Automatic, opts:OptionsPattern[]] :=
	GitCommit[repo, log, tree, {"HEAD"}, opts];
GitCommit[repo:GitRepo[id_Integer], log_String, tree_, parents_List, opts:OptionsPattern[]] :=
	Catch[Module[
		{resolvedTree = tree,
		indexTree = GL`GitIndexTree[repo],
		resolvedParents = ToGitObject[#, repo]& /@parents,
		result},

		(* figure out the tree to be committed *)
		If[resolvedTree === Automatic, resolvedTree = indexTree];
		If[GitType[resolvedTree] =!= "Tree",
			Message[GitCommit::notree]; Throw[$Failed, GitCommit]];
		If[!TrueQ[And@@(GitCommitQ[#]& /@ resolvedParents)],
			Message[GitCommit::badcommitish]; Throw[$Failed, GitCommit]];

		(* create the commit *)
		result = GL`GitCommit[id, log, resolvedTree, resolvedParents,
			OptionValue["AuthorSignature"], OptionValue["CommitterSignature"]];

		(* resolve what to do about HEAD *)
		Which[
			!GitCommitQ[result] || TrueQ[GitProperties[repo, "BareQ"]],
				0,
			indexTree === resolvedTree && isHeadBranch[repo, parents[[1]]],
				GitMoveBranch[GitProperties[repo, "HeadBranch"], result],
			indexTree === resolvedTree && ToGitObject[parents[[1]], repo] === ToGitObject["HEAD", repo], (* detached *)
				GL`GitSetHead[id, result],
			isHeadBranch[repo, parents[[1]]],
				relocateHeadBranchIfItExists[repo, result, GitCommit],
			parents[[1]] === "HEAD", (* detached *)
				GitCheckoutReference[repo, result],
			GitBranchQ[repo, parents[[1]]],
				GitMoveBranch[parents[[1]], result]
		];
		result
	], GitCommit];

GitCommit[repo:GitRepo[_Integer], log_String, tree_, parent_, opts:OptionsPattern[]] :=
	GitCommit[repo, log, tree, {parent}, opts];


Options[GitPush] = {};

GitPush[GitRepo[id_Integer], remote_String, branch_String, OptionsPattern[]] :=
	GL`GitPush[id, remote, $GitCredentialsFile, branch];


Options[GitCherryPick] = {};

(* flaky...returns true false with a changed index...decide what to do here *)
GitCherryPick[GitRepo[id_Integer], commit:(_String|_GitObject), branch_String, OptionsPattern[]] :=
	GL`GitCherryPick[id, commit];

(* much better...returns the SHA of the new commit or $Failed *)
GitCherryPick[GitRepo[id_Integer], fromCommit:(_String|_GitObject), toCommit:(_String|_GitObject), reference_String] :=
	GL`GitCherryPickCommit[id, fromCommit, toCommit, reference];
GitCherryPick[___] := $Failed;


Options[GitMerge] = {
	"CommitMessage"->None,
	"ConflictFunctions"-><||>,
	"FinalFunctions"-><||>,
	"ProgressMonitor"->None,
	"AllowCommit"->True,
	"AllowFastForward"->True,
	"AllowIndexChanges"->True};

GitMerge[repo:GitRepo[id_Integer], source_List, dest:(None|_String):"HEAD", OptionsPattern[]] :=
	Catch[Module[{result, oldCommit,realDest},
		realDest = If[dest === "HEAD" && KeyExistsQ[GitProperties[repo], "HeadBranch"],
						GitProperties[repo, "HeadBranch"],
						dest];
		If[realDest =!= None && !GitBranchQ[repo, realDest],
			Message[GitMerge::nobranch]; Throw[$Failed, GitMerge]];

		(* Create commit *)
		If[realDest =!= None, oldCommit = ToGitObject[realDest, repo]];
		result = GL`GitMerge[id, source, realDest,
			OptionValue["CommitMessage"],
			{OptionValue["ConflictFunctions"], OptionValue["FinalFunctions"], OptionValue["ProgressMonitor"]},
			OptionValue["AllowCommit"],
			OptionValue["AllowFastForward"],
			OptionValue["AllowIndexChanges"]
		];

		(* Branch management *)
		(* i.e., create "WOLFRAM_PULL_HEAD" at result, check it out, move realDest, then *)
		(* set HEAD to realDest and clean up *)
		If[realDest =!= None,
			relocateHeadBranchIfItExists[repo, result, GitMerge]];

		result],
	GitMerge];

GitMerge[repo_GitRepo, source:(_String|_GitObject), dest:(None|_String):"HEAD", opts:OptionsPattern[]] :=
	GitMerge[repo, {source}, dest, opts];


Options[GitPull] = {"Prune" -> False};

GitPull[repo:GitRepo[id_Integer], remote:(_String|None), commit_GitObject, opts:OptionsPattern[]] :=
	Catch[
		If[remote =!= None && !GitRemoteQ[repo, remote],
			Message[GitPull::badremote]; Throw[$Failed, GitPull]];
		If[!GitCommitQ[commit],
			Message[GitPull::badcommit]; Throw[$Failed, GitPull]];
		If[TrueQ[GitProperties[repo, "DetachedHeadQ"]],
			Message[GitPull::detachedhead]; Throw[$Failed, GitPull]];

		If[remote =!= None,
			GitFetch[repo, remote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]]];
		GitMerge[repo, commit, Sequence @@ FilterRules[Flatten[{opts}], Options[GitMerge]]],
	GitPull];

GitPull[repo_GitRepo, remote:(_String|None), branch_String, opts:OptionsPattern[]] :=
	Module[{commit = $Failed, remoteArg = remote},
		If[StringQ[remote] && GitRemoteQ[repo, remote],
			GitFetch[repo, remote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]];
			commit = ToGitObject[remote <> "/" <> branch, repo];
			remoteArg = None; (* prevent a double-fetch *)
		];
		If[commit === $Failed, commit = ToGitObject[branch, repo]];
		GitPull[repo, remoteArg, commit, opts]
	];

GitPull[repo_GitRepo, remote:(_String|None), opts:OptionsPattern[]] :=
	Module[{upstreamBranch, realRemote = remote},
		upstreamBranch = Quiet@GitUpstreamBranch[repo, GitProperties[repo, "HeadBranch"]];
		If[StringQ[upstreamBranch],

			If[realRemote === None,
				realRemote = FileNameSplit[upstreamBranch][[1]];
				If[!GitRemoteQ[realRemote], realRemote = None]];
			If[realRemote =!= None,
				GitFetch[repo, realRemote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]]];
			GitPull[repo, None, ToGitObject[upstreamBranch, repo], opts],

			Message[GitPull::noupstream]; $Failed]
	];

GitPull[repo_GitRepo, opts:OptionsPattern[]] := GitPull[repo, None, opts];


Options[GitCreateBranch] = {"Checkout"->False, "Force"->False, "UpstreamBranch"->None};

(* returns True/False, sets the branch on the given commit *)
GitCreateBranch[repo:GitRepo[id_Integer], branch_String, commit:(_String|_GitObject):"HEAD", OptionsPattern[]] :=
	Module[{result = GL`GitCreateBranch[id, branch, commit, TrueQ[OptionValue["Force"]]],
			remoteBranches = GitProperties[repo]["RemoteBranches"]},
		Which[
			!result,
				Null,
			MemberQ[remoteBranches, OptionValue["UpstreamBranch"]],
				GitSetUpstreamBranch[repo, branch, OptionValue["UpstreamBranch"]],
			OptionValue["UpstreamBranch"] === Automatic && MemberQ[remoteBranches, commit],
				GitSetUpstreamBranch[repo, branch, commit],
			True,
				Null
		];
		If[result && TrueQ[OptionValue["Checkout"]], GitCheckoutReference[repo, branch]];
		result
	];


Options[GitDeleteBranch] = {"Force"->False};

(* returns Null/$Failed, deletes the given branch *)
GitDeleteBranch[GitRepo[id_Integer], branch_String, OptionsPattern[]] :=
	GL`GitDeleteBranch[id, branch, TrueQ[OptionValue["Force"]]];


Options[GitMoveBranch] = {};

(* returns True/False, sets the branch on the given commit *)
GitMoveBranch["HEAD", obj:GitObject[_String, repo:GitRepo[_Integer]], source_:None, opts:OptionsPattern[]] :=
	GitMoveBranch[GitProperties[repo]["HeadBranch"], obj, source, opts];
GitMoveBranch[branch_String, GitObject[dest_String, GitRepo[id_Integer]], source_:None, OptionsPattern[]] :=
	GL`GitMoveBranch[
		id,
		StringReplace[branch, StartOfString~~"refs/heads/"~~val__:>val],
		dest, source
	];


Options[GitUpstreamBranch] = {};

(* returns the upstream branch for the given branch, or None if there is none, or $Failed *)
GitUpstreamBranch[GitRepo[id_Integer], branch_String, OptionsPattern[]] :=
	GL`GitUpstreamBranch[id, branch];


Options[GitSetUpstreamBranch] = {};

(* returns True/False, sets the branch on the given commit *)
GitSetUpstreamBranch[GitRepo[id_Integer], branch_String, upstreamBranch_String, OptionsPattern[]] :=
	GL`GitSetUpstreamBranch[id, branch, upstreamBranch];


Options[GitAddRemote] = {};

GitAddRemote[GitRepo[id_Integer], remote_String, uri_String] :=
	GL`GitAddRemote[id, remote, uri];


Options[GitDeleteRemote] = {};

GitDeleteRemote[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	GL`GitDeleteRemote[id, remote];


Options[GitCreateTrackingBranch] = {};

GitCreateTrackingBranch[repo_GitRepo, refName_String, remoteRef_String:"", OptionsPattern[]] :=
	Catch[Module[{remote,upstreamRef = remoteRef},
		If[upstreamRef==="",
			remote = "origin"; (* fix me *)
			upstreamRef = remote<>"/"<>refName;
			If[FreeQ[GitProperties[repo]["RemoteBranches"], upstreamRef],
				Message[GitCreateTrackingBranch::noBranchFound];
				Throw[$Failed, "GitCreateTrackingBranch"]
			];
		];
		GitCreateBranch[repo, refName, upstreamRef];
		GitSetUpstreamBranch[repo, refName, upstreamRef];
		(* hmm...what should this return? *)
	], "GitCreateTrackingBranch"]


(* FIXME...this is old code that needs to be updated for current documentation *)
Options[GitCheckoutFiles] = {"CheckoutStrategy"->{"Safe"}, "Notifications"-><||>};

GitCheckoutFiles[repo:GitRepo[id_Integer], refName_String, OptionsPattern[]] :=
	Module[{result},
		If[!GitCommitQ[GitRepo[id], refName] && GitCreateTrackingBranch[GitRepo[id], refName]===$Failed,

			Message[GitCheckoutFiles::refNotFound]; $Failed,
			result = If[refName === "HEAD", ToGitObject[refName, repo], GL`GitSetHead[id, refName]];

			If[result =!= $Failed, GL`GitCheckoutHead[id, OptionValue["CheckoutStrategy"], OptionValue["Notifications"]]];
			result
		]
	]


Options[GitCheckoutReference] = {
	"Create" -> False,
	"Force" -> False,
	"UpstreamBranch" -> Automatic,
	"UpstreamRemote" -> Automatic
};

GitCheckoutReference[repo:GitRepo[id_Integer], refName_String, OptionsPattern[]] :=
Module[{props = GitProperties[repo], localBranches, remoteBranches, remotes},
	localBranches = props["LocalBranches"];
	remoteBranches = Replace[OptionValue["UpstreamBranch"], {s_String :> {s}, _ :> props["RemoteBranches"]}];
	remotes = Replace[OptionValue["UpstreamRemote"], {s_String :> {s}, _ :> Keys[props["Remotes"]]}];

	If[!MemberQ[localBranches, refName],
		remoteBranches = Cases[remoteBranches, Alternatives @@ (# <> "/" <> refName &)/@ remotes];
		If[MatchQ[remoteBranches, {__String}],
			GitCreateBranch[repo, refName, First[remoteBranches], "UpstreamBranch" -> Automatic]
		]
	];
	Which[
		TrueQ @ OptionValue["Create"] && TrueQ @ GitCreateBranch[repo, refName, "Force" -> OptionValue["Force"], "Checkout" -> True],
			ToGitObject["HEAD", repo],
		TrueQ @ OptionValue["Create"],
			$Failed, (* FIXME...inconsistent return vals don't seem right *)
		ToGitObject[refName, repo] === $Failed,
			Missing["NoReference"],
		TrueQ[OptionValue["Force"]],
			GitCheckoutFiles[repo, refName, "CheckoutStrategy"->{"Force"}],
		True,
			GL`GitCheckoutReference[id, refName]
	]
];

GitCheckoutReference[repo_GitRepo, commit_GitObject, opts:OptionsPattern[]] :=
	GitCheckoutReference[repo, GitSHA[commit], opts];


(* ::Subsection::Closed:: *)
(*Bare metal Git operations*)


Options[GitExpandTree] = {};

(* returns a list of GitObjects *)
GitExpandTree[obj_GitObject, depth_:1] := 
	Switch[GitType[obj],
		"Commit", GL`GitExpandTree[GitProperties[obj]["Tree"], depth],
		"Tree", GL`GitExpandTree[obj, depth],
		_, obj];
GitExpandTree[objs:{___GitObject}, depth_:1] :=
	Map[GitExpandTree[#, depth]&, objs]


Options[GitWriteTree] = {};

(* returns a list of GitObjects *)
GitWriteTree[objs:{__Association}] := GL`GitWriteTree[objs]
GitWriteTree[objs_Dataset] := GitWriteTree[Normal[objs]]


(* returns files which are different between the two trees *)
(* some files may only exist in one of the trees *)
gitDiffTrees[tree1_GitObject, tree2_GitObject] :=
	GL`GitDiffTrees[tree1, tree2];


Options[GitReadBlob] = {CharacterEncoding->"UTF8", "PathNameHint"->None};

(* returns a list of GitObjects *)
GitReadBlob[blob_GitObject, format_:"String", OptionsPattern[]] :=
With[{readblob = GL`GitReadBlob[#, blob, OptionValue["PathNameHint"]]&},
	Which[
		format === "String" && OptionValue[CharacterEncoding] === "UTF8",
			Module[{data=readblob["ByteString"]},
				Quiet[Check[
					FromCharacterCode[ToCharacterCode[data], OptionValue[CharacterEncoding]],
					data,
					$CharacterEncoding::utf8], $CharacterEncoding::utf8]
			],
		MemberQ[$ImportFormats, format],
			ImportString[readblob["ByteString"], format, CharacterEncoding->OptionValue[CharacterEncoding]],
		True,
			Message[GitReadBlob::badformat]; $Failed
	]
]


Options[GitWriteBlob] = {CharacterEncoding->"UTF8", "PathNameHint"->None};

(* returns a list of GitObjects *)
GitWriteBlob[GitRepo[id_Integer], expr_, format_:"String", OptionsPattern[]] :=
With[{writeblob = GL`GitWriteBlob[id, #1, OptionValue["PathNameHint"], #2]&},
	Which[
		format === "String" && StringQ[expr] && OptionValue[CharacterEncoding] === "UTF8",
			writeblob["UTF8String", expr],
		MemberQ[$ExportFormats, format],
			writeblob["ByteString", ExportString[expr, format, CharacterEncoding->OptionValue[CharacterEncoding]]],
		True,
			Message[GitReadBlob::badformat]; $Failed
	]
]


(* ::Subsection::Closed:: *)
(*Merge utilities*)


(*
In handleConflicts[association], the association includes keys:

"OurFileName"
"OurBlob"
"TheirFileName"
"TheirBlob"
"AncestorFileName"
"AncestorBlob"
"Repo"
"ConflictFunctions"

If the conflict handling is successful, return a new blob. Otherwise, return $Failed.
*)


Options[handleConflicts] = {};

handleConflicts[conflict_Association] :=
Catch[Module[{cf, ancestorfilename, cfkey},
	(* choose the conflict function based on the "AncestorFileName" *)
	cf = conflict["ConflictFunctions"];
	ancestorfilename = Replace[conflict["AncestorFileName"], s_String :> FileNameTake[s]];
	Which[
		(* If there's an exact match, use it. *)
		MemberQ[ancestorfilename, Keys[cf]],
			cfkey = ancestorfilename,
		(* If there's a string match, use the first one. *)
		cfkey = SelectFirst[Keys[cf], StringMatchQ[ancestorfilename, #]&, None];
		cfkey =!= None,
			Null,
		(* otherwise, there's no appropriate conflict function. Return $Failed *)
		True,
			Message[handleConflicts::noconfunc]; Throw[$Failed, handleConflicts]
	];

	cf = cf[cfkey];
	(* If the conflict function resolves to a string, use the built-in conflictHandler with that string as the merge type *)
	Replace[cf, mergetype_String :> (cf = conflictHandler[#, mergetype]&)];

	(* if running the conflict function on this conflict returns anything other than a GitObject, return $Failed *)
	Replace[cf[conflict], Except[_Association] :> $Failed]
], handleConflicts]


conflictHandler[conflict_Association, mergetype: "MessagesMerge"] := conflictHandler[conflict, "ChooseBothLines"]


(* "ChooseOurs" and "ChooseTheirs" are format-agnostic. Use "Byte" for universality. *)
conflictHandler[conflict_Association, mergetype: ("ChooseOurs" | "ChooseTheirs")] :=
Catch[Module[{repo, blob, format},
	repo = conflict["Repo"];
	blob = If[mergetype === "ChooseOurs", conflict["OurBlob"], conflict["TheirBlob"]];
	format = "Byte";
	If[MemberQ[{blob, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	blob = GitReadBlob[blob, format];
	<|
		"Blob" -> GitWriteBlob[repo, blob, format],
		"FileName" -> If[mergetype === "ChooseOurs", conflict["OurFileName"], conflict["TheirFileName"]]
	|>

], conflictHandler]


conflictHandler[conflict_Association, mergetype: "ChooseBothLines"] :=
Catch[Module[{ancestor, our, their, repo, format, aligned, merged},

	{ancestor, our, their, repo} = conflict /@ {"AncestorBlob", "OurBlob", "TheirBlob", "Repo"};
	If[MemberQ[{ancestor, our, their, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];
	If[Not[conflict["OurFileName"] === conflict["TheirFileName"] === conflict["AncestorFileName"]],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	format = "String";
	{ancestor, our, their} = GitReadBlob[#, format]& /@ {ancestor, our, their};
	If[MemberQ[{ancestor, our, their}, Except[_String]],
		Message[handleConflicts::gitreadbloberr]; Throw[$Failed, conflictHandler]];

	{ancestor, our, their} = ImportString[#, "Lines"]& /@ {ancestor, our, their};
	If[MemberQ[{ancestor, our, their}, Except[_List]],
		Message[handleConflicts::importerr]; Throw[$Failed, conflictHandler]];

	aligned = NotebookTools`MultiAlignment[ancestor, our, their];

	merged = Flatten[Replace[aligned, {
			{a_List, b_List, a_List} (* changed by us *) :> b, 
			{a_List, a_List, b_List} (* changed by them *) :> b,
			{a_List, b_List, b_List} (* changed identically in both *) :> b, 
			{a_List, b_List, c_List} (* changed differently in both *) :> {b,c} }, {1}]];
	merged = ExportString[merged, "Lines"];

	<|
		"Blob" -> GitWriteBlob[repo, merged, format],
		"FileName" -> conflict["OurFileName"]
	|>

], conflictHandler]


conflictHandler[conflict_Association, mergetype_] := (Message[conflictHandler::unknownmergetype, mergetype]; $Failed)


(* ::Subsection::Closed:: *)
(*Typeset rules*)


giticon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];


BoxForm`MakeConditionalTextFormattingRule[GitRepo];

GitRepo /: MakeBoxes[GitRepo[id_Integer], fmt_] :=
Module[{props = GitProperties[GitRepo[id]]},
	With[{
		icon = ToBoxes[giticon],
		name = Replace[props @ If[props @ "BareQ", "GitDirectory", "WorkingDirectory"], {a_String :> ToBoxes[a, fmt], _ :> MakeBoxes[id, fmt]}],
		tooltip = ToString[GitRepo[id], InputForm]},

		TemplateBox[{MakeBoxes[id, fmt]}, "GitRepo",
				DisplayFunction -> (
					TooltipBox[PanelBox[GridBox[{{icon, name}}, BaselinePosition -> {1,2}],
						FrameMargins -> 5, BaselinePosition -> Baseline], tooltip]&)]
	]
]


GitObject /: MakeBoxes[obj:GitObject[sha_String, repo: GitRepo[_Integer]], fmt_] :=
Block[{shortsha, dir, type, bg, display},
	(*
		String and GitRepo are typically inert, so perhaps the evaluation leaks 
		here aren't that serious.
	*)
	shortsha = StringTake[sha, Min[8, StringLength[sha]]];
	dir = GitProperties[repo, "WorkingDirectory"];
	type = Replace[GitType[obj], Except[_String] :> "UnknownType"];

	bg = Switch[type,
		"Commit", Lighter[Green, 0.9],
		"Tree" | "Blob" | "AnnotatedTag", Lighter[Purple, 0.9],
		"OffsetDelta" | "ObjectDelta", Lighter[Orange, 0.9],
		_, Lighter[Red, 0.9]
	];

	display = Tooltip[
		Framed[
			Row[{Style[type, Italic], ": ", shortsha, "\[Ellipsis]"}],
			Background -> bg,
			BaselinePosition -> Baseline,
			BaseStyle -> "Panel",
			FrameMargins -> {{5,5},{3,3}},
			FrameStyle -> GrayLevel[0.8],
			RoundingRadius -> 5
		],
		Row[{type, " in ", dir, ": ", Style[sha, Bold]}]
	];
	
	(* should probably recast this as a TemplateBox eventually *)
	With[{boxes = ToBoxes[display, fmt]},
		InterpretationBox[boxes, obj]
	]
]


(* ::Subsection::Closed:: *)
(*propertiesPanel*)


propertiesPanel[repo: GitRepo[_Integer]] := propertiesPanel[repo, GitProperties[repo]]

propertiesPanel[repo: GitRepo[_Integer], properties_Association] := 
	Panel[Column[Flatten[{
		Item[Style["GitRepo Properties:", Bold], Alignment -> Center],
		Column[{
			Style["Working Directory:", Bold],
			properties["WorkingDirectory"]
		}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[properties["LocalBranches"], { branches: {__} :> branchHierarchy[repo, "", branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[properties["RemoteBranches"], { branches: {__} :> branchHierarchy[repo, "", branches], _ :> "-none-"}]
		}],
		Column[Flatten[{
			Style["Remotes:", Bold],
			Replace[properties["Remotes"], {
				remotes_Association :>
					Table[
						OpenerView[{remote, Grid[List @@@ Normal[remotes[remote]], Alignment -> Left]}, False, Method -> "Active"],
						{remote, Keys[remotes]}
					],
				_ -> {"-none-"}
			}]
		}]],

		OpenerView[{
			Style["Other Properties:", Bold],
			Grid[
				DeleteCases[List @@@ Normal[properties], {("LocalBranches" | "RemoteBranches" | "Remotes" | "WorkingDirectory"), _}],
				Alignment -> Left
			]}, True],

		Replace[GitStatus[repo], {
			status_Association :> OpenerView[{
				Style["Status:", Bold],
				Grid[List @@@ Normal[status], Alignment -> Left]}, False],
			_ -> {}
		}]

	}], Spacings -> 1.5, Dividers -> {{},{False,False,{True},False}}, FrameStyle -> LightGray, ItemSize -> Full]]

propertiesPanel[repo: GitRepo[_Integer], _] := Panel[Row[{"No properties found for ", repo}]]


propertiesPanel[obj_GitObject] := propertiesPanel[obj, GitProperties[obj]]

propertiesPanel[obj_GitObject, properties_Association] :=
	Panel[Grid[
		Join[
			{{Item[Style["GitObject Properties:", Bold], Alignment -> Center], SpanFromLeft}},
			List @@@ Normal[properties]
		],
		Alignment -> Left
	]]

propertiesPanel[obj_GitObject, _] := Panel[Row[{"No properties found for " obj}]]


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


(* 
GitRepoList returns a list whose elements are any of:
Menu[label, list of elements]
MenuItem[path]
MenuItem[label, path, opts]
path
*)

GitRepoList[a_List] := (CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = a);

GitRepoList[] := CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}, {}]

GitRepoList["Flat"] := Flatten[GitRepoList[] //. {Menu[_, a_List] :> a, MenuItem[path_] :> path, MenuItem[label_, path_, ___] :> path}]


addRepoToViewer[Dynamic[repo_]] := Replace[
	SystemDialogInput["Directory", WindowTitle -> "Select a directory containing a git repository"],
	a_String :> If[GitRepoQ[a],
		(GitRepoList[Append[GitRepoList[], AbsoluteFileName[a]]]; repo = GitOpen[a]),
		(Message[GitOpen::notarepo, a]; repo = None)
	]
]


ManageGitRepoList[] := CreateDocument[ExpressionCell[Defer[CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = #], "Input"]]& @ GitRepoList[]


viewerToolbar[Dynamic[repo_], Dynamic[branch_]] :=
	Grid[{Button[#, Enabled -> False]& /@ {"Fetch", "Pull", "Push", "Branch", "Merge", "Commit", "Reveal", "Help"}}, ItemSize -> Full]


chooseRepositoryMenu[Dynamic[repo_]] := 
	ActionMenu["Repositories",
		Flatten[{
			(Row[{FileNameTake[#], Style[" \[LongDash] " <> FileNameDrop[#], FontColor -> Gray]}] :> (repo = GitOpen[#]))& /@ GitRepoList["Flat"],
			If[GitRepoList["Flat"] === {}, {}, Delimiter],
			"Browse\[Ellipsis]" :> addRepoToViewer[Dynamic[repo]],
			Delimiter,
			"Manage Repository List\[Ellipsis]" :> ManageGitRepoList[]
		}],
		Method->"Queued"
	]


viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] := chooseRepositoryMenu[Dynamic[repo]] /; repo === None

viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] :=
Module[{props = GitProperties[repo]},
	Column[Flatten[{
		chooseRepositoryMenu[Dynamic[repo]],
		Grid[{{
			Style[props @ "WorkingDirectory", Larger],
			Button[
				Dynamic[RawBoxes @ FEPrivate`FrontEndResource["FEBitmaps", "CircleXIcon"]],
				repo = None,
				Appearance -> None]
		}}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[props @ "LocalBranches", { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[props @ "RemoteBranches", { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],

		Grid[Join[
				{{Style["Other Properties:", Bold], SpanFromLeft}},
				DeleteCases[List @@@ Normal[props], {("LocalBranches" | "RemoteBranches" | "Remotes"), _}],
				{{"Remotes", Replace[props @ "Remotes", { remotes_Association :> Tooltip[Keys[remotes], remotes], _ -> {} }]}}
			],
			Alignment -> Left
		]
	}], Spacings -> 2, Dividers -> Center, FrameStyle -> LightGray, ItemSize -> Full]
]


branchicon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];

branchopenericon = Dynamic[RawBoxes[FEPrivate`ImportImage[FrontEnd`ToFileName[{"Popups", "CodeCompletion"}, "MenuItemDirectoryTiny.png"]]]];

(* Dynamic arguments *)
formatBranch[Dynamic[repo_], Dynamic[branch_], {prefix___, name_}] := 
With[{branchname = StringJoin[Riffle[{prefix, name}, "/"]]},
	Button[
		Row[{branchicon, " ", Tooltip[name, branchname]}, BaseStyle -> Dynamic[If[CurrentValue["MouseOver"] || branch === branchname, FontColor -> RGBColor[0,0.67,0], {}]]],
		branch = branchname,
		Appearance -> None,
		BaseStyle -> {},
		DefaultBaseStyle -> {}
	]
]
(* non-Dynamic argumens *)
formatBranch[repo_, branch_, {prefix___, name_}] := Row[{branchicon, " ", Tooltip[name, FileNameJoin[{prefix, name}]]}]


formatBranchOpener[repo_, branch_, {above___, here_}, allbranches_] := 
	OpenerView[{
		Row[{branchopenericon, " ", here}],
		Column[
			Module[{branches, subbranches},
				branches = Cases[allbranches, {above, here, name_} :> {above, here, name}];
				subbranches = Cases[allbranches, {above, here, next_, __} :> {above, here, next}];
				Join[
					formatBranch[repo, branch, #]& /@ Union[branches],
					formatBranchOpener[repo, branch, #, allbranches]& /@ Union[subbranches]
				]
			],
			BaselinePosition -> {1,1},
			ItemSize -> Full
		]
	}]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], prop_String] := branchHierarchy[Dynamic[repo], Dynamic[branch], GitProperties[repo, prop]]

branchHierarchy[repo_, branch_, branchList: {___String}] := 
Module[{allbranches = StringSplit[branchList, "/"], branches, subbranches},
	branches = Cases[allbranches, {_}];
	subbranches = Cases[allbranches, {base_, __} :> {base}];
	Column[
		Join[
			formatBranch[repo, branch, #]& /@ Union[branches],
			formatBranchOpener[repo, branch, #, allbranches]& /@ Union[subbranches]
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
	}& /@ (GitProperties /@ commits),
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


(* ::Subsection::Closed:: *)
(*Initialize the library*)


InitializeGitLibrary[]


(* ::Subsection::Closed:: *)
(*Package footer*)


End[];
EndPackage[];


(* ::Section:: *)
(*Tests*)


(* ::Subsection::Closed:: *)
(*Basic tests*)


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
(*GitCommit[ToGitObject["master", repo]]*)


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


(* ::Subsection::Closed:: *)
(*Fetch/Push/Branch tests*)


(* ::Input:: *)
(*repo2=GitOpen["/Users/jfultz/wolfram/git/Test2"]*)


(* ::Input:: *)
(*GitRemoteQ[repo2,"origin"]*)


(* ::Input:: *)
(*GitProperties[repo2]*)


(* ::Input:: *)
(*GitFetch[repo2,"origin"]*)


(* ::Input:: *)
(*GitPush[repo2,"origin","master"]*)


(* ::Input:: *)
(*GitCommitQ[repo2,"origin/master"]*)


(* ::Input:: *)
(*GitCreateBranch[repo2, "master", "origin/master"]*)


(* ::Input:: *)
(*GitCreateBranch[repo2, "master", "origin/master","Force"->True]*)


(* ::Input:: *)
(*GitSHA[repo2,"origin/master"]*)


(* ::Subsection::Closed:: *)
(*Git clone*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*cloneRepo1=GitClone["ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*ResetDirectory[];*)
(*GitRepoQ[FileNameJoin[{$TemporaryDirectory,"test_repo"}]]*)
(*GitProperties[cloneRepo1]["BareQ"]*)


(* ::Input:: *)
(*cloneRepo2 = GitClone[FileNameJoin[{$TemporaryDirectory,"test_repo"}],FileNameJoin[{$TemporaryDirectory,"test_repo2"}], "Bare"->True]*)
(*GitRepoQ[FileNameJoin[{$TemporaryDirectory,"test_repo2"}]]*)
(*GitProperties[cloneRepo2]["BareQ"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo"}],DeleteContents->True];*)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo2"}],DeleteContents->True];*)


(* ::Subsection::Closed:: *)
(*Git init*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*initRepo = GitInit["init_test"]*)
(*bareInitRepo = GitInit["nested/init_test_bare","Bare"->True]*)
(*GitProperties[#,"BareQ"]&/@{initRepo,bareInitRepo}==={False,True}*)
(*GitInit["init_test"]===$Failed*)
(*GitInit["init_test","Overwrite"->True]*)
(*ResetDirectory[]*)


(* ::Subsection::Closed:: *)
(*Git remote*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*cloneRepo1=GitClone["ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*ResetDirectory[];*)
(*GitProperties[cloneRepo1]["Remotes"]*)


(* ::Input:: *)
(*GitAddRemote[cloneRepo1,"new","ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*GitProperties[cloneRepo1]["Remotes"]*)
(*GitFetch[cloneRepo1,"new"]*)
(*GitProperties[cloneRepo1]["RemoteBranches"]*)
(*GitDeleteRemote[cloneRepo1,"new"]*)
(*GitProperties[cloneRepo1]["Remotes"]*)
(*GitProperties[cloneRepo1]["RemoteBranches"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo"}],DeleteContents->True];*)


(* ::Subsection::Closed:: *)
(*Git merge*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];*)
(*SetDirectory[$TemporaryDirectory];*)
(*mergeRepo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*commit=GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "master","CommitMessage"->"Merge mergeA and mergeB into HEAD"]*)


(* ::Input:: *)
(*Sort[GitProperties[commit]["Parents"]]===Sort[ToGitObject[#,mergeRepo]&/@{"origin/mergeA","origin/mergeB","HEAD@{1}"}]*)


(* ::Input:: *)
(*GitProperties[ GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, None]]["Parents"]===Sort[ToGitObject[#,mergeRepo]&/@{"origin/mergeA","origin/mergeB"}]*)


(* ::Input:: *)
(*GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "AllowCommit"->False]*)


(* ::Input:: *)
(*GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "AllowCommit"->False,"AllowIndexChanges"->False]*)


(* ::Subsection::Closed:: *)
(*Git checkout*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];SetDirectory[$TemporaryDirectory];*)
(*repo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*GitProperties[repo]["HEAD"]*)
(*GitProperties[repo]["RemoteBranches"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,"merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,GitSHA[repo,"origin/merge1"]]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,"origin/merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,"merge2","CheckoutStrategy"->{"Force"}]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True]*)


(* ::Subsection::Closed:: *)
(*Git signature*)


(* ::Input:: *)
(*GitSignature[]*)


(* ::Input:: *)
(*GitSignature[GitOpen["c:\\wolfram\\fe\\FrontEnd"]]*)


(* ::Input:: *)
(*GitSignature[GitOpen["c:\\wolfram\\fe\\FrontEnd"],"master"]*)


(* ::Subsection::Closed:: *)
(*Git trees, commits*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];SetDirectory[$TemporaryDirectory];*)
(*repo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*Dataset[tree=GitExpandTree[GitProperties[ToGitObject["master", repo]]["Tree"]]]*)


(* ::Input:: *)
(*GitExpandTree[GitProperties[ToGitObject["master", repo]]["Tree"]]===GitExpandTree[ToGitObject["master",repo]]*)


(* ::Input:: *)
(*newsubtree=tree[[1;;3]];*)
(*newsubtreeobj=GitWriteTree[newsubtree]*)
(*Sort[newsubtree]===Sort[GitExpandTree[newsubtreeobj]]*)


(* ::Input:: *)
(*newtree=Prepend[tree[[4;;6]], <|"Object"->newsubtreeobj,"Name"->"fish","FileMode"->"Tree"|>];*)
(*newtreeobj=GitWriteTree[newtree]*)
(*Dataset[GitExpandTree[newtreeobj,1]]*)
(*Dataset[GitExpandTree[newtreeobj,Infinity]]*)


(* ::Input:: *)
(*sig=<|"Name"->"Michael Garibaldi","Email"->"garibaldi@b5.com","TimeStamp"->DateObject[List[2025,6,1],TimeObject[List[0,0,0.]],TimeZone->0.]|>;*)
(*GitCommit[repo,"Testing GitCommit",newtreeobj, "AuthorSignature"->GitProperties[ToGitObject["master", repo]]["Author"],*)
(*"CommitterSignature"->sig]*)
(*ToGitObject["HEAD",repo]===%*)
(*GitProperties[%%]["Author"]===GitProperties[ToGitObject["master~1", repo]]["Author"]*)
(*GitProperties[%%%]["Committer"]===sig*)
(*GitCreateBranch[repo, "myBranch", "origin/myBranch", "UpstreamBranch"->Automatic];*)
(*GitCommit[repo, "Testing branch commit", newtreeobj, "myBranch"]*)
(*ToGitObject["myBranch", repo] === %*)


(* ::Subsection::Closed:: *)
(*Lou tests*)


(* ::Input:: *)
(*repo = GitOpen["/files/git/fe/Fonts"]*)


(* ::Input:: *)
(*GitRemoteQ[repo, "origin"]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*GitFetch[repo, "origin"]*)


(* ::Subsection::Closed:: *)
(*Cherry-pick tests*)


(* ::Input:: *)
(*ferepo=GitOpen["~/wolfram/fe/FrontEnd"]*)


(* ::Input:: *)
(*GitSHA[ferepo,"origin/bugfix/266779"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","WOLFRAM_STASH_REBASE_HEAD"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","refs/heads/WOLFRAM_STASH_REBASE_HEAD"]*)
