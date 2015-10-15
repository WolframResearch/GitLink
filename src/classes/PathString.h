#ifndef PathString_h_
#define PathString_h_ 1

#include <string>

class PathString
{
public:
	PathString(const char* str)
		: PathString(std::string(str))
	{
	}
	PathString(const std::string& str)
		: native_(str)
		, git_(str)
	{
#if WIN
		for (auto c = git_.begin(); c < git_.end(); c++)
			if (*c == '\\')
				*c = '/';
		for (auto c = native_.begin(); c < native_.end(); c++)
			if (*c == '/')
				*c = '\\';
#endif // WIN
	};
	const std::string& native() const { return native_; }
	const std::string& git() const { return git_; }
private:
	std::string native_;
	std::string git_;
};


#endif // PathString_h_
