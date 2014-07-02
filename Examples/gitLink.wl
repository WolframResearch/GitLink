(* ::Package:: *)

(* ::Input:: *)
(*Quit*)


(* ::Input:: *)
(*FindLibrary["~/bin/gitlink"]*)


(* ::Input:: *)
(*assignToManagedRepoInstance = LibraryFunctionLoad["~/bin/gitLink","assignToManagedRepoInstance",{"UTF8String",Integer},"UTF8String"];*)


(* ::Input:: *)
(*GitRepoQ=LibraryFunctionLoad["~/bin/gitLink","GitRepoQ",{"UTF8String"},"Boolean"]*)


(* ::Input:: *)
(*GitRepoQ["/Users/jfultz/wolfram/fe/Fonts"]*)


(* ::Input:: *)
(*GitRepoQ["/Users/jfultz/wolfram/fe"]*)


(* ::Input:: *)
(*repo=CreateManagedLibraryExpression["gitRepo",gitRepo]*)


(* ::Input:: *)
(*assignToManagedRepoInstance["/Users/jfultz/wolfram/fe/Fonts",repo[[1]]]*)


(* ::Input:: *)
(*Directory[]*)


(* ::Input:: *)
(*assignToManagedRepoInstance[1,"wolfram/fe/SystemFiles"]*)


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
