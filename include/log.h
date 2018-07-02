#pragma once

#include <string>
#include <sstream>
#include <thread>
#include <iostream>
#include <utility>
#include <exception>
#include <cstdio>
#include "utils.h"

namespace SonaHttp {

/*
 *    Log("WARNING") << "something bad happened";
 */    
class Log {
public:
   
    explicit Log(const std::string& type) 
    {
        buffer_ << "[\033[35m" << localTime(time(nullptr)) << "\033[0m] " 
            << "[\033[36m" <<std::this_thread::get_id() << "\033[0m] "
            << "[\033[37m" << type << "\033[0m] ";
    }

    Log(Log&& log_) 
    { 
        if(log_.buffer_.rdbuf()->in_avail())
            buffer_ << log_.buffer_.rdbuf();
    }

    ~Log() 
    { 
        try {
            if(buffer_.rdbuf()->in_avail())
                std::cout << buffer_.rdbuf() << std::endl; 
        } catch(std::exception& e) {
            fprintf(stderr, "%s\n", e.what());
        }
    }

    template<typename T>

    auto&& operator<<(T&& val) 
    { 
        return buffer_ << std::forward<T>(val); 
    }

private:
    std::stringstream buffer_;
};

}    /**< namespace SonaHttp */
