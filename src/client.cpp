/*
* @Author: sophatvathana
* @Date:   2017-01-12 12:51:14
* @Last Modified by:   sophatvathana
* @Last Modified time: 2017-01-12 13:21:13
*/
#include "client.h"
#include "parser.h"
#include "response.h"
#include "request.h"
#include "SslConnection.h"
#include "TcpConnection.h"
#include "utils.h"
#include <boost/regex.hpp>
#include <boost/asio/ssl.hpp>
#include <boost/algorithm/string.hpp> 
#include <cstdio>

namespace SonaHttp 
{

struct ClientImpl
{
    static boost::asio::io_service& common_service()
    {
        static boost::asio::io_service service;
        if(service.stopped())
            service.reset();
        return service;
    }
};

Client::Client(boost::asio::io_service& service)
     :service_(service) 
{
    ssl_context_ = new boost::asio::ssl::context(boost::asio::ssl::context::sslv23);
    ssl_context_->set_default_verify_paths();
}

Client::Client() : Client(ClientImpl::common_service())
{
}

Client::~Client() { delete ssl_context_; }

void Client::apply()
{
    service_.run();
    service_.reset();           //apply
}

void Client::request(const std::string& method, const std::string& url,
    std::function<void(ResponsePtr)> res_handler,
    std::function<void(RequestPtr)> req_handler)
{
    /** http://user:pass@server:port/path?query */
    static const boost::regex url_reg("(((http|https)://))?((((?!@).)*)@)?"
        "(((?![/\\?]).)+)(.+)?", boost::regex::icase);    
    boost::smatch results;
    if(boost::regex_search(url, results, url_reg)) 
    {
        std::string scheme = "http";

        if(results[3].matched) 
        {
            scheme = results.str(3);
            boost::to_lower(scheme);
        }

        std::string auth{};
        if(results[5].matched)
            auth = results.str(5);

        std::string host = results.str(7);

        std::string path = "/";
        if(results[9].matched)
            path = results.str(9);

        if(path[0] != '/')
            path = "/" + path;

        std::string port = scheme == "https" ? "443" : "80";
        static const boost::regex host_port_reg("(((?!:).)*)(:([0-9]+))?");
        if(boost::regex_search(host, results, host_port_reg)) 
        {
            host = results.str(1);
            if(results[4].matched)
                port = results.str(4);
        }
        ConnectionPtr connection;
        if(scheme == "http") 
        {
            connection = std::make_shared<TcpConnection>(service_);
        } 
        else if(scheme == "https") 
        {
            connection = std::make_shared<SslConnection>(service_, *ssl_context_);
        } 
        else 
        {
            assert(false);    
        }

        connection->asyncConnect(host, port, [=](ConnectionPtr conn) 
        {
            if(conn) 
            {
                auto req = std::make_shared<Request>(conn);
                req->setMethod(method);
                auto pos = path.find("?");
                if(pos == path.npos) 
                {
                    req->setPath(path);
                } 
                else 
                {
                    req->setPath(path.substr(0, pos));
                    req->setQueryString(path.substr(pos + 1, path.size()));
                }
                req->setVersion("HTTP/1.1");
                if(enable_cookie_) 
                {
                    std::unique_lock<std::mutex> lck(cookie_mutex_);
                    add_cookie_to_request(req, scheme, host);
                }
                

                if(auth != "")
                    req->basicAuth(auth);

                req_handler(req);

                if(!req->getHeader("Host"))
                    req->addHeader("Host", host + ":" + port);
                
                req->setHeader("Connection", "close");

                parseResponse(conn, [=](ResponsePtr response) 
                {
                    if(response) 
                    {
                        response->discardConnection();
                        if(enable_cookie_) 
                        {
                            std::unique_lock<std::mutex> lck(cookie_mutex_);
                            add_cookie_to_cookie_jar(response, host);
                        }
                        res_handler(response);
                    } 
                    else 
                    {
                        res_handler(nullptr);
                    }
                });
            } 
            else 
            {
                req_handler(nullptr);
                res_handler(nullptr);
            }
        });
    } 
    else 
    {
        res_handler(nullptr);
    }
}

void Client::add_cookie_to_request(RequestPtr req, const std::string& scheme, const std::string& host)
{
    for(auto iter = cookie_jar_.begin(); iter != cookie_jar_.end();) 
    {
        if(iter->expires != 0 && iter->expires < time(nullptr)) 
        {
            cookie_jar_.erase(iter);
        } 
        else 
        {
            ++iter;
        }
    }
    for(auto& c : cookie_jar_) 
    {
        if(!isPathMatch(req->getPath(), c.path))
            continue;
        if(!isDomainMatch(host, c.domain))
            continue;
        if(c.secure && scheme != "https")
            continue;
        req->setCookie({c.key, c.val});
    }
}

void Client::add_cookie_to_cookie_jar(ResponsePtr res, const std::string& host)
{
    for(auto c : res->cookieJar()) 
    {
        bool is_new = true;
        if(c.domain == "")
            c.domain = host;
        if(c.path == "")
            c.path = "/";
        for(auto& oc : cookie_jar_) 
        {
            if(oc.key == c.key) 
            {
                oc = c;
                is_new = false;
                break;
            }
        }
        if(is_new)
            cookie_jar_.push_back(c);
    }
}

}    /**< namespace SonaHttp */
