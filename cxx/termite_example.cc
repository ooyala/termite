#include "termite.h"
using namespace termite;

int main(int argc, char **argv)
{
  string app("MyApp");
  Termite* logger = Termite::GetTermite(app);
  logger->SetProperty("mykey", "my value");
  logger->SetProperty("mykey2", "my value2");

  int result = EXIT_SUCCESS;
  TERMITE_INFO(logger, "Entering application.");
  logger->ClearProperty("mykey");
  TERMITE_ERROR(logger, "Oh No!");
  logger->ResetProperties();
  TERMITE_INFO(logger, "Exiting application.");

  return result;
}