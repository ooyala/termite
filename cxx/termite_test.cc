#include <gtest/gtest.h>
#include <iostream>
#include <fstream>
#include <string>
using namespace std;

#include "termite.h"
using namespace termite;

string ReadAndNormalizeLog(const char *filename) {
    string result("");
    string line;
    ifstream logfile (filename);
    if (logfile.is_open()) {
        while (logfile.good()) {
            getline(logfile, line);
            line = line.replace(0, 24, ""); // strip the time
            int openBracket = line.find('[');
            if (openBracket >= 0) {
                int closeBracket = line.find(']');
                line = line.replace(openBracket,closeBracket-openBracket,"["); // strip thread
                result += line + "\n";
            }
        }
        logfile.close();
    }
    return result;
}

TEST (TermiteTest, All) {
    EXPECT_EQ(
"DEBUG MyApp []: Debug {\"mykey\":\"my value\",\"mykey2\":\"my value2\"}\n\
INFO  MyApp []: Info {\"mykey2\":\"my value2\"}\n\
WARN  MyApp []: Warn {}\n\
ERROR MyApp []: Error {}\n\
FATAL MyApp []: Fatal {}\n", ReadAndNormalizeLog("termite_test.log"));
}

int main(int argc, char **argv)
{
    remove("termite_test.log");
    Termite* logger = Termite::GetTermite("MyApp", "termite_test.log", false);
    logger->SetProperty("mykey", "my value");
    logger->SetProperty("mykey2", "my value2");

    TERMITE_DEBUG(logger, "Debug");
    logger->ClearProperty("mykey");
    TERMITE_INFO(logger, "Info");
    logger->ResetProperties();
    TERMITE_WARN(logger, "Warn");
    TERMITE_ERROR(logger, "Error");
    TERMITE_FATAL(logger, "Fatal");

    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
