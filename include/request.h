#pragma once

#include <string>
#include <vector>
#include <memory>
#include <map>
#include <sstream>
#include "package.h"
#include "header.h"
#include "cookie.h"
#include "log.h"

namespace SonaHttp 
{

class Request : public Package, 
    public std::enable_shared_from_this<Request> 
{
public :
    using Package::Package;

    ~Request() override;
            
    std::string getPath() { return path_; }

    void setPath(const std::string& path) { path_ = path; }


    std::string getQueryString() { return query_; }

    void setQueryString(const std::string& query) { query_ = query; }
 

    std::string getMethod() { return method_; }

  
    void setMethod(const std::string& method) { method_ = method; }

 
    std::string getVersion() { return version_; }
    
    bool keepAlive() 
    {        
        std::string* connection_opt = getHeader("Connection");
        if(connection_opt) {
            if(strcasecmp(connection_opt->c_str(), "Keep-alive") == 0) 
            {
                return true;
            }  
            else 
            {
                return false;
            }
        }
        if(getVersion() == "HTTP/1.1")
            return true; 
        return false;
    }
 
    void setVersion(const std::string& version) { version_ = version; }
  
    void setCookie(const request_cookie_t& cookie) 
    {
        std::string header_val = cookie.key;
        if(cookie.val != "")
            header_val += "=" + cookie.val;

        std::string *h = getHeader("Cookie");
        if(h) 
        {
            *h += "; " + header_val;
        } 
        else 
        {
            addHeader("Cookie", header_val);
        }
    }
  
    const std::string* getCookieValue(const std::string& key) 
    {
        for(auto& rc : cookie_jar_) 
        {
            if(rc.key == key)
                return &rc.val;
        }
        return nullptr;
    }

    const std::vector<request_cookie_t>& cookieJar() 
    {
        return cookie_jar_;
    }

    void parseParams(const std::string& param_list)
    {
        std::map<std::string, std::string> map;
        StringTokenizer st(param_list, '&');
        while(st.hasMoreTokens()) 
        {
            StringTokenizer key_val_st(st.nextToken(), '=');
            if(!key_val_st.hasMoreTokens())
                continue;
            std::string key = key_val_st.nextToken();
            urlDecode(key);
            std::string val;
            if(key_val_st.hasMoreTokens()) 
            {
                val = key_val_st.nextToken();
                urlDecode(val);
            }
            map[key] = val;    
        }
        param_map_ = map;
    }

    std::string getParamValue(const std::string& key) 
    {
        return param_map_[key];
    }

    void flush();

    void basicAuth(const std::string& auth);

    std::string basicAuthInfo();

    std::string proxyAuthInfo();

private:
    std::string method_;

    std::string path_;

    std::string query_;

    std::map<std::string, std::string> param_map_;

    std::string version_;

    std::vector<request_cookie_t> cookie_jar_;    

    void parseCookie() 
    {
        std::string* cookie_header = getHeader("Cookie");
        if(cookie_header) 
        {
            cookie_jar_ = parseRequestCookie(*cookie_header);
        }
    }
    friend void parseRequest(ConnectionPtr, std::function<void(RequestPtr)>);
};

}    /**< namespace SonaHttp */
