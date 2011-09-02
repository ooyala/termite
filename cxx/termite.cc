#include "termite.h"
#include <syslog.h>
#include <log4cxx/propertyconfigurator.h>
#include <log4cxx/patternlayout.h>
#include <log4cxx/net/syslogappender.h>
#include <json_spirit.h>

using namespace log4cxx;
using namespace log4cxx::helpers;
using namespace log4cxx::net;
using namespace termite;

// TODO(yuval): make this thread-safe in a better way than a mutex on every call
namespace termite {
  map<string, Termite*> Termite::termites_;
  boost::mutex Termite::static_mutex_;


  Termite::Termite(string name) {
    logger_ = Logger::getLogger(name);
    configureLogger();
    Properties properties_;
    boost::mutex inst_mutex_;
    isCacheCurrent_ = true;

    // TODO(yuval): read manifest file and include json properties
  }

  void Termite::SetProperty(string key, string value) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_[key.c_str()] = value;
  }

  void Termite::ClearProperty(string key) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_.erase(key.c_str());
  }

  void Termite::ResetProperties() {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_.clear();
  }

  Termite* Termite::GetTermite(string name) {
    boost::mutex::scoped_lock mylock(static_mutex_);

    Termite* termite = termites_[name.c_str()];
    if (termite == NULL) {
      termite = new Termite(name);
      termites_[name.c_str()] = termite;
    }
    return termite;
  }

  void Termite::ForceLog(LevelPtr level, string message) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    if (!isCacheCurrent_) {
      RebuildPropertyCache();
    }

    logger_->forcedLog(level, message + cachedPropStr_);
  }

  void Termite::RebuildPropertyCache() {
    json_spirit::Object json;
    for (Properties::iterator p = properties_.begin(); p != properties_.end(); ++p) {
      json.push_back(json_spirit::Pair(p->first, p->second));
    }
    cachedPropStr_ = " " + json_spirit::write(json);
    isCacheCurrent_ = true;
  }

  // Configure log4cxx
  void Termite::configureLogger() {
    PatternLayout *layout = new PatternLayout("%c [%t]: %m%n");
    SyslogAppender *appender = new SyslogAppender(layout, "127.0.0.1", LOG_LOCAL7);
    BasicConfigurator::configure(appender);
  }

  bool Termite::IsTraceEnabled() { return logger_->isTraceEnabled(); }
  bool Termite::IsDebugEnabled() { return logger_->isDebugEnabled(); }
  bool Termite::IsInfoEnabled() { return logger_->isInfoEnabled(); }
  bool Termite::IsWarnEnabled() { return logger_->isWarnEnabled(); }
  bool Termite::IsErrorEnabled() { return logger_->isErrorEnabled(); }
  bool Termite::IsFatalEnabled() { return logger_->isFatalEnabled(); }

}