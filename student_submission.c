#include <stdio.h>
#include <stdlib.h>

int main()
{
    float num1=0.0f, num2=0.0f;

    printf("Enter two numbers\n");
    scanf("%f%f", &num1, &num2);

    printf("Addition Result = %f\n", num1 + num2);
    printf("Subtraction Result = %f\n", num1 - num2);
    printf("Multiplication Result = %f\n", num1 * num2);
   
    if (num2 == 0.0f)
    {
        printf("ERROR: division-by-zero. Aborting...\n");
        return EXIT_FAILURE;
    }
    else
    {
           printf("Division Result = %f\n", num1 / num2);
    }

    printf("Successful execution. Exiting program...\n");

    return EXIT_SUCCESS;
}