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

RemoteConnector::RemoteConnector(WolframLibraryData libData, git_repository* repo, const char* remoteName, const char* privateKeyFile)
	: remoteName_(remoteName == NULL ? "" : remoteName)
	, keyFile_(privateKeyFile == NULL ? "" : privateKeyFile)
	, libData_(libData)
{
	git_remote_init_callbacks(&callbacks_, GIT_REMOTE_CALLBACKS_VERSION);
	callbacks_.credentials = &AcquireCredsCallback;
	callbacks_.payload = this;
	callbacks_.transfer_progress = &TransferProgressCallback;
	callbacks_.sideband_progress = &SidebandProgressCallback;

	if (!remoteName || git_remote_lookup(&remote_, repo, remoteName))
		remote_ = NULL;

	isValidRemote_ = (remote_ != NULL);
}

RemoteConnector::~RemoteConnector()
{
	if (remote_)
		git_remote_free(remote_);
}


bool RemoteConnector::clone(git_repository** repo, const char* uri, const char* localPath, git_clone_options* options, const MLExpr& progressFunction)
{
	options->fetch_opts.callbacks = callbacks_;
	progressFunction_ = progressFunction;

	int err = git_clone(repo, uri, localPath, options);
	if (err != 0 && credentialAttempts_ == 1 && triedSshAgent_)
		err = git_clone(repo, uri, localPath, options); // Necessary under Windows, not on MacOS
	progressFunction_ = MLExpr();
	credentialAttempts_ = 0;
	return (err == 0);
}

bool RemoteConnector::connect_(git_direction direction)
{
	int result = git_remote_connect(remote_, direction, &callbacks_, NULL, NULL);
	if (result != 0 && credentialAttempts_ == 1 && triedSshAgent_)
		result = git_remote_connect(remote_, direction, &callbacks_, NULL, NULL);
	credentialAttempts_ = 0;
	return (result == 0);
}


int RemoteConnector::AcquireCredsCallback(git_cred** cred, const char* url, const char *username, unsigned int allowed_types, void* payload)
{
	RemoteConnector* connector = static_cast<RemoteConnector*>(payload);
	const int MaxAttempts = 3;
	connector->credentialAttempts_++;

	if (connector->credentialAttempts_ > MaxAttempts)
		return -1;

	if ((allowed_types & GIT_CREDTYPE_DEFAULT) != 0)
	{
		git_cred_default_new(cred);
	}
	else if ((allowed_types & GIT_CREDTYPE_SSH_KEY) != 0 && !connector->keyFile_.empty())
	{
		if (connector->credentialAttempts_ == 1)
		{
			git_cred_ssh_key_from_agent(cred, username);
			connector->triedSshAgent_ = true;
		}
		else
		{
			std::string keyFile(connector->keyFile_);
			git_cred_ssh_key_new(cred, username, NULL, keyFile.c_str(), "");
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
	if (std::chrono::steady_clock::now() - connector->lastProgressCheckpoint_ < std::chrono::milliseconds(200))
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
