#include<stdio.h>
int main(int argc, char *argv[])
{
    int i;
    printf("Total Number of args: %d\n",argc);
    for(i=0;i<argc;i++)
    {
        printf("%dth argv: %s\n",i, argv[i]);
    }
    return 0;
}