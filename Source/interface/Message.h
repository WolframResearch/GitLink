#ifndef Message_h_
#define Message_h_ 1

namespace Message
{
	extern const char* Success;
	extern const char* Unimplemented;
	extern const char* ArgCount;
	extern const char* BadRepo; // probably should never happen if we do our error-checking right
	extern const char* BadRemote;
	extern const char* FetchFailed;
	extern const char* BadConfiguration;
	extern const char* RemoteConnectionFailed;
	extern const char* DownloadFailed;
	extern const char* UpdateTipsFailed;
}
#endif // Message_h_

