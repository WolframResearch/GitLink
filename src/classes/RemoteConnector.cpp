/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <string>
#include <cstdio>
#include "mathlink.h"
#include "RemoteConnector.h"
#include "WolframLibrary.h"
#include "MLHelper.h"

RemoteConnector::RemoteConnector()
	: keyFile_(NULL)
{
}

RemoteConnector::RemoteConnector(WolframLibraryData libData, const char* theKeyFile)
	: keyFile_(theKeyFile == NULL ? NULL : strdup(theKeyFile))
	, libData_(libData)
{
	if (theKeyFile != NULL)
		keyFile_ = strdup(theKeyFile);
	git_remote_init_callbacks(&callbacks_, GIT_REMOTE_CALLBACKS_VERSION);
	callbacks_.credentials = &AcquireCredsCallback;
	callbacks_.payload = this;
	callbacks_.transfer_progress = &TransferProgressCallback;
	callbacks_.sideband_progress = &SidebandProgressCallback;
}

RemoteConnector::~RemoteConnector()
{
	free((void*)keyFile_);
}

RemoteConnector& RemoteConnector::operator=(const RemoteConnector& connector)
{
	free((void*)keyFile_);
	keyFile_ = strdup(connector.keyFile_);
	checkForSshAgent_ = connector.checkForSshAgent_;
	return *this;
}


bool RemoteConnector::clone(git_repository** repo, const char* uri, const char* localPath, git_clone_options* options, const MLExpr& progressFunction)
{
	options->remote_callbacks = callbacks_;
	progressFunction_ = progressFunction;

	int err = git_clone(repo, uri, localPath, options);
	if (err != 0 && checkForSshAgent_)
	{
		checkForSshAgent_ = false;
		err = git_clone(repo, uri, localPath, options);
	}
	progressFunction_ = MLExpr();
	return (err == 0);
}

bool RemoteConnector::connect_(git_remote* remote, git_direction direction)
{
	if (git_remote_set_callbacks(remote, &callbacks_) != 0)
		return false;
	if (git_remote_connect(remote, direction) == 0)
		return true;
	else if (checkForSshAgent_)
	{
		checkForSshAgent_ = false;
		giterr_clear();
		return (git_remote_connect(remote, direction) == 0);
	}
	return false;
}


int RemoteConnector::AcquireCredsCallback(git_cred** cred, const char* url, const char *username, unsigned int allowed_types, void* payload)
{
	RemoteConnector* connector = static_cast<RemoteConnector*>(payload);

	if ((allowed_types & GIT_CREDTYPE_DEFAULT) != 0)
	{
		git_cred_default_new(cred);
	}
	else if ((allowed_types & GIT_CREDTYPE_SSH_KEY) != 0 && connector->keyFile_ != NULL)
	{
		if (connector->checkForSshAgent_)
			git_cred_ssh_key_from_agent(cred, username);
		else
		{
			std::string keyFile(connector->keyFile_);
			std::string pubKeyFile(connector->keyFile_);
			pubKeyFile += ".pub";
			git_cred_ssh_key_new(cred, username, pubKeyFile.c_str(), keyFile.c_str(), "");
		}
	}
	else if ((allowed_types & GIT_CREDTYPE_USERPASS_PLAINTEXT) != 0)
	{
		// git_cred_userpass_plaintext(cred, userName, password);
	}
	else if ((allowed_types & GIT_CREDTYPE_SSH_INTERACTIVE) != 0)
	{
		// git_cred_ssh_interactive_new(cred, username_from_url, promptCallback, payload);
	}
	else if ((allowed_types & GIT_CREDTYPE_SSH_CUSTOM) != 0)
	{
		// git_cred_ssh_custom_new(cred, username_from_url, promptCallback, payload);
	}
	// not implemented and doesn't need to be
	// else if ((allowed_types & GIT_CREDTYPE_SSH_CUSTOM) != 0)
	return 0;
}

int RemoteConnector::TransferProgressCallback(const git_transfer_progress* stats, void* payload)
{
	RemoteConnector* connector = static_cast<RemoteConnector*>(payload);
	if (connector->libData_ && connector->libData_->AbortQ())
		return -1;
	if (std::chrono::steady_clock::now() - connector->lastProgressCheckpoint_ < std::chrono::milliseconds(50))
		return 0;
	if (!connector->progressFunction_.isNull() && !connector->progressFunction_.testSymbol("None"))
	{
		MLHelper helper(connector->libData_->getMathLink(connector->libData_));
		helper.beginFunction("EvaluatePacket");
		helper.beginFunction(connector->progressFunction_);
		helper.beginFunction("Association");

		helper.putRule("TotalObjects");
		helper.putInt(stats->total_objects);

		helper.putRule("IndexedObjects");
		helper.putInt(stats->indexed_objects);

		helper.putRule("ReceivedObjects");
		helper.putInt(stats->received_objects);

		helper.putRule("LocalObjects");
		helper.putInt(stats->local_objects);

		helper.putRule("TotalDeltas");
		helper.putInt(stats->total_deltas);

		helper.putRule("IndexedDeltas");
		helper.putInt(stats->indexed_deltas);

		helper.processAndIgnore(connector->libData_);

		connector->lastProgressCheckpoint_ = std::chrono::steady_clock::now();
	}
	return 0;
}

int RemoteConnector::SidebandProgressCallback(const char* str, int len, void* payload)
{
	RemoteConnector* connector = static_cast<RemoteConnector*>(payload);
	if (connector->libData_ && connector->libData_->AbortQ())
		return -1;
	return 0;
}
