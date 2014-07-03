(* ::Package:: *)

(* ::Input:: *)
(*Quit*)


(* ::Subsection:: *)
(*Init*)


FindLibrary["~/bin/gitlink"];


assignToManagedRepoInstance[repo_String, GitRepo[id_Integer]] :=
	If[LibraryFunctionLoad["~/bin/gitLink", "assignToManagedRepoInstance",
		{"UTF8String", Integer}, "UTF8String"][repo, id] === "", $Failed, GitRepo[id]]


GitRepoQ=LibraryFunctionLoad["~/bin/gitLink", "GitRepoQ", {"UTF8String"}, "Boolean"];


GitRemoteQ[GitRepo[id_Integer], remote_String]:=
	LibraryFunctionLoad["~/bin/gitLink", "GitRemoteQ",
		{Integer, "UTF8String"}, "Boolean"][id, remote];


GitBranchQ[GitRepo[id_Integer], branch_String]:=
	LibraryFunctionLoad["~/bin/gitLink", "GitBranchQ",
		{Integer, "UTF8String"}, "Boolean"][id, branch];


GitOpen[repo_String]:=
	If[GitRepoQ[repo],
		assignToManagedRepoInstance[repo, CreateManagedLibraryExpression["gitRepo",GitRepo]],
		$Failed];	


GitFetch[GitRepo[id_Integer], remote_String, opts___]:=
	LibraryFunctionLoad["~/bin/gitLink", "GitFetch",
		{Integer, "UTF8String", "Boolean"}, "UTF8String"][id, remote, TrueQ["Prune" /. {opts} /. {"Prune"->False}]];


GitPush[GitRepo[id_Integer], remote_String, branch_String]:=
	LibraryFunctionLoad["~/bin/gitLink", "GitPush",
		{Integer, "UTF8String", "UTF8String"}, "UTF8String"][id, remote, branch];


(* ::Subsection:: *)
(*Tests*)


(* ::Input:: *)
(*{GitRepoQ["/Users/jfultz/wolfram/fe/Fonts"],GitRepoQ["/Users/jfultz/wolfram/fe"]}*)


(* ::Input:: *)
(*repo=GitOpen["/Users/jfultz/wolfram/fe/Fonts"]*)


(* ::Input:: *)
(*{GitRemoteQ[repo,"origin"],GitRemoteQ[repo,"foo"]}*)


(* ::Input:: *)
(*{GitBranchQ[repo,"master"],GitBranchQ[repo,"foo"]}*)


(* ::Input:: *)
(*repo2=GitOpen["/Users/jfultz/wolfram/git/Test2"]*)
(*GitFetch[repo2,"origin"]*)


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




repo
