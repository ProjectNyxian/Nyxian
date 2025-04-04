#include <stdbool.h>

#include "../interpreter.h"


static int trueValue = 1;
static int falseValue = 0;

const char StdboolDefs[] = "typedef int bool;";

void StdboolSetupFunc(Picoc *pc)
{
    VariableDefinePlatformVar(pc, NULL, "true", &pc->IntType,
    	(union AnyValue*)&trueValue, false);
    VariableDefinePlatformVar(pc, NULL, "false", &pc->IntType,
    	(union AnyValue*)&falseValue, false);
    VariableDefinePlatformVar(pc, NULL, "__bool_true_false_are_defined",
    	&pc->IntType, (union AnyValue*)&trueValue, false);
}
