#pragma once
#include <ctime>
#include <string>
#include <vector>
#include <cstdio>
#include "exception.h"

namespace SonaHttp {

struct BufferOverflow : Exception {
    using Exception::Exception;
    ~BufferOverflow() override;
};

struct TokenError : Exception {
    using Exception::Exception;
    ~TokenError() override;
};

inline std::string
localTime(time_t t)
{
    char lc_time[64] = { 0 };
    struct tm *lct = localtime(&t);
    if(!strftime(lc_time, sizeof(lc_time), "%a, %d-%h-%G %H:%M:%S", lct))
        DEBUG_THROW(BufferOverflow, "while get local time");
    return lc_time;
}

inline std::string
gmtTime(time_t t)
{
    char gmt_time[64] = { 0 };
    struct tm *gmt = gmtime(&t);
    if(!strftime(gmt_time, sizeof(gmt_time), "%a, %d-%h-%G %H:%M:%S", gmt))
        DEBUG_THROW(BufferOverflow, "while get gmt time");
    return gmt_time;
}

template<typename _type, typename... _tParams>
constexpr auto
peek(_type&& arg, _tParams&&...)
{
        return std::forward<_type>(arg);
}

template<typename _tContainer, typename _tItem> 
std::vector<_tContainer> 
explode(_tContainer& c, const _tItem& i)
{
        _tContainer buff;
        std::vector<_tContainer> v;
    
        for(auto n:c)
        {
                if(n != i) {
                        buff += n;  
                } else if(n == i && buff.size() != 0) { 
                                v.push_back(buff); 
                                buff = _tContainer(); 
                }
        }

        if(buff.size() != 0)  
                v.push_back(buff);
    
        return v;
}

template<typename _tContainer, typename _tItem> 
std::vector<_tContainer> 
explode(_tContainer& c, const _tItem& item, const _tItem& lefts...)
{
    for(auto& it : c) {
        if(it == item)
            it = peek(lefts);
    }
    return explode(c, lefts);    
}

/**
 * \brief Split a string by given charactor.
 */
class StringTokenizer
{
public:
    StringTokenizer(std::string str, char delim1, char lefts...)
        :tokens(explode(str, delim1, lefts)) {}

    /**
     * \param str The string to be splited.
     * \param delim Dest string was splited by this charactor.
     */ 
    StringTokenizer(std::string str, char delim = ' ')
        :tokens(explode(str, delim)) {}

        StringTokenizer() = default;
        StringTokenizer(const StringTokenizer &) = default;

    /**
     * \brief Check if there are more tokens in the tokenizer.
     * \return If have, true, else, false.
     */
        bool hasMoreTokens() { return !tokens.empty(); }

    /**
     * \brief Get next token in the tokenizer.
     * \return Next token.
     */
        std::string nextToken()
        {
                if(tokens.empty())
                        DEBUG_THROW(TokenError, "No more tokens");
                std::string ret = tokens.front();
                tokens.erase(tokens.begin());
                return ret;
        }

        std::vector<std::string>::iterator begin() { return tokens.begin(); };
        std::vector<std::string>::iterator end() { return tokens.end(); };
        size_t size() { return tokens.size(); }
private:
        std::vector<std::string> tokens;
};

time_t gmtToTime(const std::string& gmt_time);
std::string urlEncode(const std::string& url);
bool urlDecode(std::string& url);
bool isValidIPAddress(const std::string& addr);
bool isDomainMatch(const std::string& addr, std::string base);
bool isPathMatch(std::string path, std::string base);
std::string getParam(std::string addr, std::string name);
std::string getByPattern(std::string source, std::string pattern, int index);
}       /**< namespace SonaHttp */
