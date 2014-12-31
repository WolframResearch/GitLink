/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "RepoInterface.h"
#include "GitLinkRepository.h"
#include "GitTree.h"
#include "Message.h"
#include <climits>


EXTERN_C DLLEXPORT int GitExpandTree(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitTree tree(lnk);
	MLExpr depth(lnk);
	int depthInt = 1;

	if (depth.isInteger())
		depthInt = depth.getInt();
	else if (depth.testSymbol("Infinity") || depth.testHead("DirectedInfinity"))
		depthInt = INT_MAX;

	if (tree.isValid())
		tree.writeContents(lnk, depthInt);
	else
	{
		tree.mlHandleError(libData, "GitExpandTree");
		MLPutSymbol(lnk, "$Failed");
	}

	return LIBRARY_NO_ERROR;
}


