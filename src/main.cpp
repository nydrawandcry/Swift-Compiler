#include <stdio.h>

extern FILE *yyin;
extern int yyparse(void);

extern int lexerErrors;
extern int parseErrors;

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");

    if (yyin == NULL)
    {
        fprintf(stderr, "Error opening file: %s\n", argv[1]);
        return 1;
    }

    int parseResult = yyparse();

    fclose(yyin);

    if (parseResult != 0 || parseErrors != 0 || lexerErrors != 0)
    {
        return 1;
    }

    return 0;
}