// Runs every test suite in one binary, so bin/test reports them together.
#include <QGuiApplication>

int runOmacraftTests(int argc, char **argv);
int runIsoTests(int argc, char **argv);

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    int failures = 0;
    failures += runOmacraftTests(argc, argv);
    failures += runIsoTests(argc, argv);
    return failures;
}
