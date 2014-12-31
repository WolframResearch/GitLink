/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "GitLinkRepository.h"
#include "GitTree.h"

#include "Message.h"
#include "MLHelper.h"


GitTree::GitTree(const GitLinkRepository& repo, git_index* index)
	: repo_(repo.key())
{
	if (!git_index_write_tree_to(&oid_, index, repo.repo()))
		git_tree_lookup(&tree_, repo.repo(), &oid_);
}

GitTree::GitTree(const MLExpr& expr)
	: repo_(expr)
{
	MLExpr e = expr;

	if (e.testSymbol("Automatic") && repo_.isValid())
	{
		git_index* index;
		if (!git_repository_index(&index, repo_.repo()))
		{
			if (!git_index_write_tree(&oid_, index))
				git_tree_lookup(&tree_, repo_.repo(), &oid_);

			git_index_free(index);
		}
		return;
	}
	if (e.testHead("GitObject") && e.length() == 2 && e.part(1).isString())
		e = e.part(1);
	if (repo_.isValid() && e.isString())
	{
		const char* sha = e.asString();
		if (git_oid_fromstr(&oid_, sha) != 0)
			errCode_ = Message::BadSHA;
		else if (git_tree_lookup(&tree_, repo_.repo(), &oid_) != 0)
			errCode_ = Message::NoTree;
	}
}

GitTree::~GitTree()
{
	if (tree_)
		git_tree_free(tree_);
}

void GitTree::write(MLINK lnk) const
{
	if (tree_ != NULL)
	{
		MLHelper helper(lnk);
		helper.putGitObject(oid_, repo_);
	}
	else
		MLPutSymbol(lnk, "$Failed");
}

void GitTree::writeContents(MLINK lnk, int depth) const
{
	if (tree_ != NULL)
	{
		MLHelper helper(lnk);
		helper_ = &helper;
		helper.beginList();

		depth_ = depth;
		git_tree_walk(tree_, GIT_TREEWALK_PRE, GitTree::writeTreeEntry, (void*)this);
		depth_ = 1;
		helper_ = NULL;
	}
	else
		MLPutSymbol(lnk, "$Failed");
}

int GitTree::writeTreeEntry(const char* root, const git_tree_entry* entry, void* payload)
{
	const GitTree* tree = (const GitTree*) payload;
	MLHelper* helper = tree->helper_;

	// Expand out subtrees if requested
	// git_tree_walk() would do this for us automatically if we returned 0 from this
	// callback.  But the problem is that we wouldn't know when we were done expanding
	// a tree, so we can't track depth.  I.e., one could implement depth == 1 or depth == MAX_INT,
	// but depth == 2 would be very challenging.  So, instead, we just create a new tree walker
	// on the subtree.
	if (tree->depth_ > 1 && git_tree_entry_type(entry) == GIT_OBJ_TREE)
	{
		size_t oldRootSize = tree->root_.size();
		if (!tree->root_.empty())
			tree->root_ += '/';
		tree->root_ += git_tree_entry_name(entry);
		git_tree* subtree;
		git_tree_lookup(&subtree, tree->repo_.repo(), git_tree_entry_id(entry));
		tree->depth_--;
		git_tree_walk(subtree, GIT_TREEWALK_PRE, GitTree::writeTreeEntry, payload);
		tree->depth_++;
		git_tree_free(subtree);
		tree->root_.resize(oldRootSize);
		return 1;
	}

	helper->beginFunction("Association");

	helper->putRule("Type");
	if (strcmp(OtypeToString(git_tree_entry_type(entry)), "None") == 0)
		helper->putSymbol("None");
	else
		helper->putString(OtypeToString(git_tree_entry_type(entry)));

	helper->putRule("Object");
	helper->putGitObject(*git_tree_entry_id(entry), tree->repo_);

	helper->putRule("Root");
	helper->putString(tree->root_.c_str());

	helper->putRule("Name");
	helper->putString(git_tree_entry_name(entry));

	helper->putRule("FileMode");
	switch (git_tree_entry_filemode(entry))
	{
		case GIT_FILEMODE_TREE:				helper->putString("Tree");		break;
		case GIT_FILEMODE_BLOB:				helper->putString("Blob");		break;
		case GIT_FILEMODE_BLOB_EXECUTABLE:	helper->putString("BlobExecutable");	break;
		case GIT_FILEMODE_LINK:				helper->putString("Link");		break;
		case GIT_FILEMODE_COMMIT:			helper->putString("Commit");	break;
	}

	helper->endFunction();
	return 1;
}
