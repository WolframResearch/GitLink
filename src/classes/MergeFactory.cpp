/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <vector>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "MergeFactory.h"

#include "GitLinkRepository.h"
#include "GitTree.h"
#include "Message.h"

bool MergeFactory::initialize(MergeFactoryMergeType mergeType)
{
	if (!repo_.isValid())
	{
		resultFailureType_ = "InvalidArguments";
		return false;
	}

	if (argv_.length() < 8)
	{
		resultFailureType_ = "InvalidSource";
		return false;
	}

	// Arg2: Merge heads
	mergeSources_ = {repo_, argv_.part(2)};
	if (!mergeSources_.isValid())
	{
		resultFailureType_ = "InvalidSource";
		return false;
	}

	// Arg3: Destination reference
	if (argv_.part(3).isString())
	{
		dest_ = new GitLinkCommit(repo_, argv_.part(3));
		if (!dest_->isValid())
		{
			resultFailureType_ = "InvalidDestination";
			return false;
		}
		mergeSources_.push_front(*dest_);
	}
	else
	{
		// None is acceptable, as long as there are enough branches to create a merge
		if (!argv_.part(3).testSymbol("None"))
			resultFailureType_ = "InvalidDestination";
		else if (mergeSources_.size() < 2)
			resultFailureType_ = "InvalidSource";
		else
			resultFailureType_ = NULL;
		if (resultFailureType_)
			return false;
	}

	// Arg4: Commit message
	if (argv_.part(4).isString())
	{
		MLExpr arg4 = argv_.part(4); // retain the expr long enough so that we can get the string
		commitMessage_ = arg4.asString();
	}

	// Arg5: Callbacks
	if (argv_.part(5).isList() && argv_.part(5).length() == 3)
	{
		conflictFunctions_ = argv_.part(5).part(1);
		finalFunctions_ = argv_.part(5).part(2);
		progressFunction_ = argv_.part(5).part(3);
	}
	else
	{
		resultFailureType_ = "InvalidArguments";
		return false;
	}

	// Args 6, 7, 8: AllowCommit, AllowFastForward, AllowIndexChanges
	allowCommit_ = argv_.part(6).testSymbol("True");
	allowFastForward_ = argv_.part(7).testSymbol("True");
	allowIndexChanges_ = argv_.part(8).testSymbol("True");

	return true;
}

void MergeFactory::mlHandleError(WolframLibraryData libData, const char* functionName) const
{
	if (!repo_.isValid())
	{
		repo_.mlHandleError(libData, functionName);
		return;
	}
	GitLinkSuperClass::mlHandleError(libData, functionName);
};

void MergeFactory::write(MLINK lnk)
{
	if (resultSuccess_)
		GitLinkCommit(repo_, &resultOid_).write(lnk);
	else
	{
		MLPutFunction(lnk, "Failure", 2);
		MLPutString(lnk, resultFailureType_);
		if (resultFailureData_.isNull())
			MLPutFunction(lnk, "Association", 0);
		else
			resultFailureData_.putToLink(lnk);
	}
}

void MergeFactory::doMerge(WolframLibraryData libData)
{
	if (!buildStrippedMergeSources_())
		return;

	if (strippedMergeSources_.size() == 1 && allowFastForward_)
	{
		resultSuccess_ = true;
		git_oid_cpy(&resultOid_, strippedMergeSources_.front().oid());
		return;
	}

	git_tree* workingTree = NULL;
	git_index* workingIndex = NULL;
	git_tree* ancestorTree = ancestorCopyTree_();
	git_merge_options opts;
	MLExpr remainingConflicts;
	bool indexWriteFailed;
	bool mergeFailed;

	git_merge_init_options(&opts, GIT_MERGE_OPTIONS_VERSION);

	if (ancestorTree == NULL)
	{
		// with the error-checking that's already happened, this should be impossible
		resultFailureType_ = "InvalidSource";
		return;
	}

	for (GitLinkCommit& c : strippedMergeSources_)
	{
		git_tree* incomingTree = c.copyTree();

		// exit early first time through
		if (!workingTree)
		{
			workingTree = incomingTree;
			continue;
		}

		// merge the trees
		if (workingIndex)
			git_index_free(workingIndex);	
		mergeFailed = git_merge_trees(&workingIndex, repo_.repo(), ancestorTree, workingTree, incomingTree, &opts);
		git_tree_free(incomingTree);
		git_tree_free(workingTree);

		remainingConflicts = handleConflicts(libData, workingIndex);

		// serialize the resulting tree and go again
		git_oid workingTreeOid;
		indexWriteFailed = (mergeFailed ||
			git_index_write_tree_to(&workingTreeOid, workingIndex, repo_.repo()) ||
			git_object_lookup((git_object**) &workingTree, repo_.repo(), &workingTreeOid, GIT_OBJ_TREE));

		if (indexWriteFailed)
		{
			if (!mergeFailed)
				git_index_free(workingIndex);
			workingIndex = NULL;
			break;
		}
	}

	git_tree_free(ancestorTree);
	if (workingTree)
		git_tree_free(workingTree);

	if (remainingConflicts.length() > 0)
	{
		MLHelper failureData(libData->getMathLinkEnvironment(libData), resultFailureData_);
		resultFailureType_ = "UnresolvedConflicts";

		failureData.beginFunction("Association");
		failureData.putRule("MessageTemplate");
		failureData.beginFunction("MessageName");
		failureData.putSymbol("GitMerge");
		failureData.putString("hasconflicts");
		failureData.endFunction();
		failureData.putRule("Conflicts", remainingConflicts);
		failureData.endFunction();
	}
	else if (indexWriteFailed || mergeFailed)
	{
		resultFailureType_ = "GitWriteFailed";
	}
	else if (allowCommit_)
	{
		GitTree tree(repo_, workingIndex);
		GitLinkCommit commit(repo_, tree, mergeSources_, NULL, NULL, commitMessage_.c_str());
		if (commit.isValid())
		{
			resultSuccess_ = true;
			git_oid_cpy(&resultOid_, commit.oid());
		}
		else
			resultFailureType_ = "GitWriteFailed";
	}
	else if (allowIndexChanges_)
	{
		// check for changes to existing index
		if (!git_index_write(workingIndex))
			resultSuccess_ = true;
		else
			resultFailureType_ = "WorkingTreeConflicts";
	}
	else
		resultFailureType_ = "MergeNotAllowed";

	git_index_free(workingIndex);
}

MLExpr MergeFactory::handleConflicts(WolframLibraryData libData, git_index* index)
{
	if (!git_index_has_conflicts(index))
		return MLExpr();

	git_index_conflict_iterator* i;
	git_index_conflict_iterator_new(&i, index);

	const git_index_entry* ancestor;
	const git_index_entry* ours;
	const git_index_entry* theirs;
	MLExpr result;
	MLINK lnk = libData->getMathLink(libData);
	MLHelper resultHelper(MLLinkEnvironment(lnk), result);

	resultHelper.beginList();

	while (!git_index_conflict_next(&ancestor, &ours, &theirs, i))
	{
		MLHelper helper(lnk);
		helper.beginFunction("EvaluatePacket");
		helper.beginFunction("GitLink`Private`handleConflicts");

		helper.beginFunction("Association");

		putConflictData_(helper, ancestor, ours, theirs, true);

		helper.putRule("Repo");
		helper.putRepo(repo_);

		helper.putRule("ConflictFunctions");
		helper.putExpr(conflictFunctions_);

		helper.processAndIgnore(libData);

		resultHelper.beginFunction("Association");
		putConflictData_(resultHelper, ancestor, ours, theirs, false);
		resultHelper.endFunction();
	}
	git_index_conflict_iterator_free(i);

	resultHelper.endList();

	return result;
}

void MergeFactory::putConflictData_(MLHelper& helper, const git_index_entry* ancestor,
	const git_index_entry* ours, const git_index_entry* theirs, bool withContents)
{
	git_blob* blob;

	helper.putRule("OurFileName", ours->path);
	helper.putRule("TheirFileName", theirs->path);
	helper.putRule("AncestorFileName");
	if (ancestor)
		helper.putString(ancestor->path);
	else
		helper.putSymbol("None");

	if (withContents)
	{
		git_blob_lookup(&blob, repo_.repo(), &ours->id);
		helper.putRule("OurContents", blob);
		git_blob_free(blob);
		
		git_blob_lookup(&blob, repo_.repo(), &theirs->id);
		helper.putRule("TheirContents", blob);
		git_blob_free(blob);

		if (ancestor)
		{
			git_blob_lookup(&blob, repo_.repo(), &ancestor->id);
			helper.putRule("AncestorContents", blob);
			git_blob_free(blob);
		}
		else
		{
			helper.putRule("AncestorContents");
			helper.putSymbol("None");
		}
	}
	else
	{
		helper.putRule("OurBlob", ours->id, repo_);
		helper.putRule("TheirBlob", theirs->id, repo_);
		if (ancestor)
			helper.putRule("AncestorBlob", ancestor->id, repo_);
		else
		{
			helper.putRule("AncestorSHA");
			helper.putSymbol("None");
		}
	}
}

bool MergeFactory::buildStrippedMergeSources_()
{
	if (!strippedMergeSources_.empty())
		return true;
	bool identity = true; // if all of mergeSources_ are identical, succeed in the right way
	for (GitLinkCommit& i : mergeSources_)
	{
		bool isFFParent = false;
		for (GitLinkCommit& j : mergeSources_)
		{
			git_oid mergeBaseOid;
			if (i == j)
				continue;
			identity = false;
			if (!git_merge_base(&mergeBaseOid, repo_.repo(), i.oid(), j.oid()))
				isFFParent = git_oid_equal(i.oid(), &mergeBaseOid);
			else
			{
				resultFailureType_ = "MergeNotAllowed";
				return false;
			}
		}
		if (identity)
		{
			resultSuccess_ = true;
			git_oid_cpy(&resultOid_, mergeSources_.front().oid());
			return false; // do nothing more...we succeeded
		}
		if (!isFFParent || !allowFastForward_)
			strippedMergeSources_.push_back(i);
	}
	return true;
}

git_tree* MergeFactory::ancestorCopyTree_()
{
	std::vector<git_oid> oidList(2);
	int length = 0;
	for (const GitLinkCommit& c : strippedMergeSources_)
	{
		oidList.push_back(git_oid());
		git_oid_cpy(&oidList[length], c.oid());
		length++;
	}

	git_oid mergeBaseOid;
	git_tree* returnValue = NULL;

	if (!git_merge_base_many(&mergeBaseOid, repo_.repo(), length, &oidList[0]))
		returnValue = GitLinkCommit(repo_, &mergeBaseOid).copyTree();

	return returnValue;
}
