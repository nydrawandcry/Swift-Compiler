#include <stdio.h>

extern FILE *yyin;
extern int yylex(void);

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

    yylex();

    fclose(yyin);
    return 0;
}