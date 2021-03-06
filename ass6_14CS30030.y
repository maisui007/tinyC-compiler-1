
%{
    #include <stdio.h>
    #include "ass6_14CS30030_translator.h"//the header file for translator
    #include<iostream>
    #include<string>
    #include<list>
    //These variables are declared in globalVariables.c file
   	void yyerror(const char*);
    extern int yylex(void);
    extern std::vector<Quad*> quadVector;
	extern int quadPointer;
	extern symbolTable* global;
	extern symbolTable *symTab;
	extern Symbol* curSym;
	extern Type* globalType;
	extern string array_name;
	extern symbolTable *external;
	extern int stringcount;
	extern int labelcount;
	extern std::vector<label> labelTable;
    using namespace std;//the c++ library is used most of the time

 %}

%union{
	int intval; //to store the integer values
	char* cval; //to store the character values
	float fval; //to store the double king of values
	char* sval; //to store the string values.Not implemented this time
	struct Symbol *loc; //the SymbolItem pointer 
	struct funcPointer *funcP; //the pointer structure contataining the symbolTable pointer. We have to enclose it in struct because class can't be used as type in lex inside union
	struct arg_list* args; //list of expression pointers
	struct Expression *expr; //The main structue which is expression pointer
	struct Type* typeptr; //The type is used to contain the type pointers for different type specifiers.
	struct opPointer *op;//The operation code pointer contatining op_code, for unary opearators
}

%token AUTO BREAK CASE CHAR CONST CONTINUE DEFAULT DO DOUBLE ELSE ENUM EXTERN
%token FLOAT FOR GOTO IF INLINE INT LONG REGISTER RESTRICT RETURN SHORT SIGNED SIZEOF STATIC STRUCT SWITCH
%token TYPEDEF UNION UNSIGNED VOID VOLATILE WHILE BOOL COMPLEX IMAGINARY
%token ACC
%token INC
%token DEC
%token SHL
%token SHR
%token LESSTHAN
%token LTE
%token GREATERTHAN
%token GTE
%token EQUAL
%token NEQUAL
%token LogAND
%token LogOR
%token ELIP
%token AssSTAR
%token AssDIV
%token AssMOD
%token AssPLUS
%token AssMINUS
%token AssSHL
%token AssSHR
%token AssBinAND
%token AssXOR
%token AssBinOR
%token <loc> IDENTIFIER
%token <intval> INTEGER_CONSTANT
%token <fval> FLOATING_CONSTANT
%token <cval> CHARACTER_CONSTANT
%token ENUMERATION_CONSTANT
%token <sval> STRING_LITERAL
%token SINGLE_COMMENT
%token MULTI_COMMENT
%token RSB
%token RCB
%token RPA
%token LSB
%token LCB
%token LPA
%token FULLSTOP
%token BITWISEAND
%token BITWISEOR
%token MUL
%token PLUSop
%token MINUSop
%token TILDE
%token APO 
%token DIV
%token PERCENT
%token POWER
%token QUES
%token COLON
%token SEMICOLON
%token COMMA
%token HASH
%token ASSG
%type<expr> translation_unit
%type<expr> external_declaration
%type<expr> function_definition
%type<expr> declaration_list_opt
%type<expr> declaration_list

%type<expr> statement
%type<expr> labeled_statement
%type<expr> compound_statement
%type<expr> expression_statement
%type<expr> expression_opt
%type<expr> selection_statement
%type<expr> iteration_statement
%type<expr> jump_statement
%type<expr> block_item
%type<expr> block_item_list
%type<expr> block_item_list_opt

%type<expr> 		expression
%type<expr>    		assignment_expression
%type<expr> 		constant_expression
%type<expr> 		conditional_expression
%type<expr> 		unary_expression
%type<expr> 		logical_OR_expression
%type<expr> 		logical_AND_expression
%type<expr> 		inclusive_OR_expression
%type<expr>  		exclusive_OR_expression
%type<expr> 		AND_expression
%type<expr> 		equality_expression
%type<expr> 		relational_expression
%type<expr> 		shift_expression
%type<expr> 		additive_expression
%type<expr> 		multiplicative_expression
%type<expr> 		cast_expression
%type<expr> 		postfix_expression
%type<expr> 		primary_expression
%type<expr> 		constant
%type<args>			argument_expression_list
%type<args>			argument_expression_list_opt


%type<intval>		M;
%type<intval>		H;
%type<expr>			N;
%type<op>			unary_operator;

%type<typeptr> 		declaration_specifiers
%type<typeptr> 		declaration_specifiers_opt
%type<typeptr> 		type_specifier
%type<typeptr> 		specifier_qualifier_list
%type<typeptr> 		specifier_qualifier_list_opt
%type<typeptr> 		type_name
%type<typeptr> 		pointer_opt
%type<typeptr> 		pointer

%type<funcP>		F;

%type<loc> 			identifier_list
%type<loc> 			declaration
%type<loc> 			init_declarator
%type<loc> 			init_declarator_list
%type<loc> 			init_declarator_list_opt
%type<loc>			declarator
%type<loc> 			direct_declarator

%type<expr>			initializer
%type<expr>			initializer_list
%type<expr>			identifier_opt
%type<expr> 		assignment_expression_opt

%start start_exec //a new start non terminal to facilitate backpatching

%%

start_exec:				translation_unit
						{
							//Notice the nextlist attribute used
							backpatch($1->nextlist,quadPointer);//clearly we have to point all the dangling pointers to the end of prgram
							emit(ENDPROGRAM,"====");//The endprogram quad
						}



translation_unit:		external_declaration									|
						translation_unit external_declaration
						;

external_declaration:	function_definition										|
						declaration//just for the sake of type matching, although externals declarations can be skipped, I have added that functionality
						{
							$$ = new expression;
							$$->loc = $1;
						}	;

//The augmentation is done here.
//when funciton declaration is done, the F will make the current symbol Table to point to a new symbolTable associated with funciton name.
//After the execution, it will make the symbol table back to the earlier one
//The H non terminal will emit a quadPointer which will tell when the function Defintion has started
function_definition:	declaration_specifiers declarator declaration_list_opt F H compound_statement
						{
							symTab = $4->symTabP->parent;//Going back to earlier symbol table
							$$ = new expression;
							$$->nextlist = $6->nextlist;//The nextlist will be taken up the order
							quadVector[$5]->result=$2->name;//Telling the name of function
						}
						;

declaration_list_opt:	declaration_list 										|
						/*epsilon*/
						;

declaration_list:		declaration 											|
						declaration_list declaration
						;

//The augmentated non terminal F, it will be used to change the current symbol table to the one which will be pointed by the new function
//If it already contains the symbolTable pointer then it will change the currentSymblTable to that function symboltable
F:						{
							$$ = new funcPointer;
							if(curSym->symTabPointer)
							{
								$$->symTabP = curSym->symTabPointer;
								$$->symTabP->parent = symTab;
							}
							else
							{
								$$->symTabP = new symbolTable;
								$$->symTabP->parent = symTab;
							}
							symTab = $$->symTabP;//making the symbol table pointer to point to the desired table
						}
						;
//This non terminal is used to identify when the function declaration is taking place and it will emit a pointer before that place to enable proper labelling
H:						{
							$$ = quadPointer;
							emit(FUNCTION_OP,"----");
						}
						;

/******************************************************************************************/
//  Statements

//The beginnig statement are direct assignments.
statement:				labeled_statement										|
						compound_statement										|
						expression_statement									|
						selection_statement										|
						iteration_statement										|
						jump_statement		
						;
//This has been ignored as given in the assignment
labeled_statement:		IDENTIFIER COLON statement {$$=$3;}								|
						CASE constant_expression COLON statement{$$=$4;} 					|
						DEFAULT COLON statement {$$=$3;}
						;
//This is where nextlist comes into action
//It will be contatining the nextlist of dangling quads for a statement block
compound_statement:		LCB block_item_list_opt RCB 
							{
								$$ = new expression;
								$$->nextlist = $2->nextlist;
							}
						;

//In case of epsilon transition nothing new is going to take place else it will be directly assigning the nextlist to other by default rule
block_item_list_opt:	block_item_list 										|	
						/*epsilon*/
						{	
							$$ = new expression;
							$$->nextlist = 0;
						}
						;
//The augmentated grammar.
//It will facilitate the backpatching of each statement in case a block item consists of dangling gotos which is quite common for nested statements
block_item_list:		block_item 											|
						block_item_list M block_item
						{
							$$ = new expression;
							backpatch($1->nextlist,$2);//backpatching the dangling goto's to next instruction
							$$->nextlist = $3->nextlist;//associating the nextlist with the new block_item
						}
						;

block_item:				declaration {$$->nextlist = 0;}	//in case of declaration,no nextlist is generated	
						|
						statement
						;						

expression_statement:	expression_opt SEMICOLON
						;

expression_opt:			expression 												|
						/*epsilon*/{$$=0;}
						;

//The augmented if and if-else statements. The augmentation is done based on class illustrations.
//The if else condition has numerous possible gotos so they have been handled accordingly.
selection_statement:	IF LPA expression RPA N M statement N ELSE M statement N	
						{
							$$ = new expression;
							backpatch($5->nextlist,quadPointer);
							if($3->loc->type->type!=_BOOL)//checking the expression type,if it is not bool,then convert it to bool
								conv2bool($3);//converting the expression to bool type
							backpatch($3->truelist,$6);
							backpatch($3->falselist,$10);
							list<int>* temp1 = merge($7->nextlist,$8->nextlist);
							list<int>* temp2 = merge($11->nextlist,$12->nextlist);
							$$->nextlist = merge(temp1,temp2);//creating the nextlist
						}
						|//The augmentation is done in the if statement. It is almost similar to the last one
						IF LPA expression RPA N M statement N
						{
							$$ = new expression;
							if($3->type->type!=_BOOL)
							{	
								conv2bool($3);
							}
							backpatch($5->nextlist,quadPointer);							
							backpatch($3->truelist,$6);
							if($7->nextlist!=NULL)
							{	
								list<int>* temp = merge($7->nextlist,$8->nextlist);
								$$->nextlist = merge($3->falselist,temp);
							}
							else
							{
								$$->nextlist = merge($3->falselist,$8->nextlist);
							}
						}
						|//SWITCH statement not required by assignment requirements
						SWITCH LPA expression RPA statement {$$=$5;}
						;

						//The augmented while statement. The dangling pointers are taken in nextlist

iteration_statement:	WHILE M LPA expression RPA N M statement 												
						{
							$$ = new expression;
							emit(_goto,to_string($2));
							backpatch($6->nextlist,quadPointer);
							if($4->loc->type->type!=_BOOL)//again conversion to bool expression
							conv2bool($4);
							backpatch($4->truelist,$7);//backpatching truelist
							backpatch($8->nextlist,$2);
							$$->nextlist = $4->falselist;// assigning nextlist
						}
						|
						//The do while statement is also augmented according to class illustrations
						DO M statement M WHILE LPA expression RPA N SEMICOLON 										
						{
							$$ = new expression;
							backpatch($9->nextlist,quadPointer);//To make it go to the next instruction							
							if($7->loc->type->type!=_BOOL)//again bool type checking
							conv2bool($7);
							backpatch($7->truelist,$2);//backpatching truelist
							backpatch($3->nextlist,$4);
							$$->nextlist = $7->falselist;//assigning nextlist
							
						}
						|
						//The handling of for loop. The handling is same as done in class illustrations
						//The augmentations are done based on the next quads to go
						FOR LPA expression_opt SEMICOLON M expression_opt N SEMICOLON M expression_opt N RPA M statement 		
						{
							$$ = new expression;
							emit(_goto,to_string($9));
							backpatch($7->nextlist,quadPointer);
							if($6->loc->type->type!=_BOOL)
							conv2bool($6);
							backpatch($6->truelist,$13);
							backpatch($11->nextlist,$5);
							backpatch($14->nextlist,$9);							
							$$->nextlist = $6->falselist;//generated nextlist
						}
						|
						FOR LPA declaration expression_opt SEMICOLON expression_opt RPA statement{$$=$8;}
						;


//only return type is handled
jump_statement:			GOTO IDENTIFIER SEMICOLON 									|
						CONTINUE SEMICOLON 											|
						BREAK SEMICOLON 												|
						RETURN expression_opt SEMICOLON 
						{
							Symbol* symb = symTab->lookup("$return_value$");
							//do the typechecking with the return type of the function
							if($2)
							{

								if(symb->type->type==$2->loc->type->type)
								{
							
									emit(_RETURN,$2->loc->name);//return the value given in case of same type
								}
								else
								{
							
									if(symb->type->type==_VOID)
									{
										cerr<<"Wrong return type"<<endl;//No return value 
									}
									else
									{
										convert($2,symb->type->type);//type casting
										emit(_RETURN,$2->loc->name);//emitting the return
									}
									
								}
								$$ = new expression;
							}
							else
							{

								if(symb->type->type==_VOID)
								{
							
									emit(_RETURN,"NULL");//void type return. Will simply print return
								}
								else
								{
									cerr<<"Wrong return type"<<endl;
								}
								$$ = new expression;
							}
							
						}
						;

// Declarations 

declaration:			declaration_specifiers init_declarator_list_opt SEMICOLON 
						{
							$$ = $2;
						}
						;

init_declarator_list_opt: init_declarator_list 								
						{
							$$=$1;
						}
						|
						/*epsilon*/{$$ =0;}
						;

declaration_specifiers:	storage_class_specifier declaration_specifiers_opt 		|
						type_specifier declaration_specifiers_opt 
						{

							$$=createType($1->type);
							globalType = createType($1->type);						
						}
						|
						type_qualifier declaration_specifiers_opt 				|
						function_specifier declaration_specifiers_opt
						;

declaration_specifiers_opt: declaration_specifiers 								|
						/*epsilon*/{$$=0;}
						;

init_declarator_list:	init_declarator 										|
						init_declarator_list COMMA init_declarator
						;

init_declarator:		declarator 												|
						declarator ASSG initializer
						{
							updateSymbolInitVal($1,$3->loc->name);
							emit(COPY,$1->name,$3->loc->name);
							$$ = $1;
							
						}
						;

storage_class_specifier: 	EXTERN 												|
							STATIC  											|
							AUTO 												|
							REGISTER
						;
//Getting the global type. That global type will be used to update the current identifier
type_specifier:			VOID {$$=createType(_VOID); globalType = createType(_VOID);}			|
						CHAR {$$=createType(_CHAR);globalType = createType(_CHAR);}				|
						SHORT 			{$$=0;}										|
						INT	{$$=createType(_INT);globalType = createType(_INT);}				|
						LONG 			{$$=0;}										|
						FLOAT 			{$$=0;}										|
						DOUBLE {$$=createType(_DOUBLE);globalType = createType(_DOUBLE);}		|
						SIGNED	{$$=0;}												|
						UNSIGNED {$$=0;}												|
						BOOL 	{$$=0;}												|
						COMPLEX {$$=0;}												|
						IMAGINARY{$$=0;} 												|
						enum_specifier{$$=0;}
						;			


specifier_qualifier_list: type_specifier specifier_qualifier_list_opt 	{$$=$1;}		|
						type_qualifier specifier_qualifier_list_opt{$$=0;}
						;	

specifier_qualifier_list_opt: specifier_qualifier_list 							|
						/*epsilon*/{$$=0;}
						;
//not required
enum_specifier:			ENUM identifier_opt LCB enumerator_list RCB 			|
						ENUM identifier_opt LCB enumerator_list COMMA RCB 		|																			
						ENUM IDENTIFIER
						;
//assigning symbol pointer
identifier_opt:			IDENTIFIER 												|
						/*epsilon*/{$$->loc = 0;$$->int_val=-1;}
						;

enumerator_list:		enumerator 												|
						enumerator_list COMMA enumerator
						;

enumerator:				enumeration_constant 									|
						enumeration_constant ASSG constant_expression
						;

type_qualifier:			CONST 													|
						RESTRICT 												|
						VOLATILE
						;

function_specifier:		INLINE
						;
//to handle the type int**.. i.e. when we have a list of pointer type and it goes to base type.
declarator :			pointer_opt direct_declarator
						{
							if($1!=0)
							{
								Type *ptr;
								ptr = $1;
								while(ptr->next)ptr=ptr->next;
								if($2->type->type==_FUNCTION)
								{
									Symbol *ret = $2->symTabPointer->lookup("$return_value$");
									ptr->next = ret->type;
									updateSymbol(ret,ptr);
								}
								else
								{
									ptr->next = $2->type;
									updateSymbol($2,$1);
								}
								$$ = $2;
							}
							else
							{
								$$ = $2;
							}
						}
						;

pointer_opt:			pointer {$$=$1;}												|
						/*epsilon*/{$$=0;}
						;

direct_declarator:		IDENTIFIER 	
						{
							curSym=$1;//It will hold the value of current symbol being read.
							//It will help us to decide the function table pointer handling in the F non terminal grammar
							$$ = $1;
							updateSymbol($1,globalType);//upadating the type
						}																	|
						LPA declarator RPA 	
						{
							$$ = $2;
						}
						|
						//The array declaration is here 
						direct_declarator LSB type_qualifier_list_opt assignment_expression_opt RSB 		
						{
							if($4->int_val>0)//Will happen only when we have integer value inside square brackets
							{
								$$ = $1;				
								Type *baseType = getBaseType($1->type);
								Type *temp = createType(_ARRAY);
								temp->width = $4->int_val * $1->type->width;
								temp->count = $4->int_val;

								Type *arTemp = $1->type;								
								Type *t;								
								
								//handling the count for calculating the width
								Type* p = NULL;
								t = arTemp;								
								if(t->type==_ARRAY)
								{
									while(t->type ==_ARRAY)
									{
										p = t;
										t = t->next;
									}
									p->next = NULL;
									reverse(&arTemp);
									temp->next = arTemp;
									t = temp;									
									int width = baseType->width;									
									while(t && t->type==_ARRAY)
									{	
										t->width = t->count * width;								
										width = t->width;
										t =  t->next;
									}
									reverse(&temp);								
								}
								
								p = NULL;
								t = temp;								
								while(t!=NULL)
								{	
									p = t;
									t =  t->next;
								}								
								p->next = baseType;

								$1->type = temp;							
																				
							}
							else//error handling
							{
								cerr<<"Wrong array declaration"<<endl;
							}
						}
						|																										
						direct_declarator LSB STATIC type_qualifier_list_opt assignment_expression RSB 		|
						direct_declarator LSB type_qualifier_list STATIC assignment_expression RSB 			|
						direct_declarator LSB type_qualifier_list_opt MUL RSB 								|
						direct_declarator LPA F parameter_type_list RPA
						{
							//funciton declaration 
							//Note that F will make the symTab to point to the symbolTable associated with currentSymbol being read curSym
							curSym = $1;
							$1->symTabPointer = $3->symTabP;
							if($3->symTabP->param==0)//it will help to know the number of parameters in a function which would prove beneficial during function calling
							{
								$3->symTabP->param = $3->symTabP->symbols.size();
							}
							Type* temp = $1->type;
							Type *t = createType(_FUNCTION);//making the function type
							Symbol *retval = symTab->lookup("$return_value$");//adding the return value in the _FUNCTION symbol table for type checking in future
							updateSymbol(retval,temp);
							symTab=$3->symTabP->parent;
							updateSymbol($1,t);
							
						} 										
						|//same semantics as above
						direct_declarator LPA F identifier_list_opt RPA
						{
							curSym = $1;
							$1->symTabPointer = $3->symTabP;
							if($3->symTabP->param==0)
							{
								$3->symTabP->param = $3->symTabP->symbols.size();
							}
							Type* temp = $1->type;
							Type *t = createType(_FUNCTION);
							
							Symbol *retval = symTab->lookup("$return_value$");
							updateSymbol(retval,temp);


							symTab=$3->symTabP->parent;
							updateSymbol($1,t);
						}
						;

type_qualifier_list_opt:type_qualifier_list 									|
						/*epsilon*/{}
						;

assignment_expression_opt:assignment_expression 								|
						/*epsilon*/{$$ = new expression;$$->loc = 0;$$->int_val=-1;}
						;

identifier_list_opt:	identifier_list 										|
						/*epsilon*/
						;

//pointer type handling
pointer:				MUL type_qualifier_list_opt 
						{
							$$ = createType(_POINTER);
						}
						|
						MUL type_qualifier_list_opt pointer
						{
							if($3 != NULL)
							{
								$$ = createType(_POINTER);
								$$->next = $3;
							}
							else
							{
								$$ = createType(_POINTER);
							}
						}
						;

type_qualifier_list:	type_qualifier 											|
						type_qualifier_list type_qualifier
						;

parameter_type_list:	parameter_list 											|
						parameter_list COMMA ELIP
						;

parameter_list:			parameter_declaration 									|
						parameter_list COMMA parameter_declaration
						;

parameter_declaration:	declaration_specifiers declarator 						|
						declaration_specifiers
						;

identifier_list :		IDENTIFIER 												|
						identifier_list COMMA IDENTIFIER
						;

type_name:				specifier_qualifier_list
						;

initializer:			assignment_expression 									|
						LCB initializer_list RCB {$$=$2;}								|
						LCB initializer_list COMMA RCB{$$=$2;}
						;

initializer_list:		designation_opt initializer 							|
						initializer_list COMMA designation_opt initializer
						;																																															

designation_opt:		designation 											|
						/*epsilon*/
						;

designation:			designator_list ASSG
						;

designator_list:		designator 												|
						designator_list designator
						;

designator:				LSB constant_expression RSB 							|
						FULLSTOP IDENTIFIER
						;
/*****************************************************************************************************/
// Expressions  semantics handling

expression :			assignment_expression 									|
						expression COMMA assignment_expression
						;

constant_expression:	conditional_expression
						;

assignment_expression:	conditional_expression 									|
						unary_expression  ASSG assignment_expression
						{
							
							if($1->array_oc==0 && $1->isPointer==0)//when the left side is neither array nor pointer
							{	

								if($3->type->type!=_BOOL)//bool type is handled separately	
								{	
							
									if($3->type->type!=$1->type->type)														
										convert($3,$1->type->type);//typechecking and subsequent conversion
									
									emit(COPY,$1->loc->name,$3->loc->name);
									$$ = $1;								
								}
								else
								{  //handling of bool type
									backpatch($3->truelist,quadPointer);
									backpatch($3->falselist,quadPointer);
									emit(COPY,$1->loc->name,$3->loc->name);
									$$ = $1;
								}						
							}
							else if($1->isPointer==0)
							{	//array exists on left side
								emit(ARRAYLEFT,array_name,$1->loc->name,$3->loc->name);								
								$$ = $1;
							
							}
							else 
							{
								//The pointer occurred on left side.
								string res = "*";
								res.append($1->loc->name);
								emit(COPY,res,$3->loc->name);
								$$ = $1;
							}


						}			
						;																																		

assignment_operator:	ASSG 													|
						AssSTAR 											|
						AssDIV 												|
						AssMOD 												|
						AssPLUS 												|
						AssMINUS 												|
						AssSHL 										|
						AssSHR 										|
						AssBinAND 												|
						AssXOR 												|
						AssBinOR
						;

conditional_expression: logical_OR_expression 									|
						logical_OR_expression N QUES M expression N COLON M conditional_expression	
						{
							//The handling of ternary operator. The semantics is same as done in class illustrations
							$$ = new expression;
							$$->loc = symTab->gentemp();
							$$->type = $5->type;
							emit(COPY,$$->loc->name,$9->loc->name);
							list<int> *l = makelist(quadPointer);
							emit(_goto,"---");
							backpatch($6->nextlist,quadPointer);
							emit(COPY,$$->loc->name,$5->loc->name);
							l = merge(l,makelist(quadPointer));
							emit(_goto,"---");
							backpatch($2->nextlist,quadPointer);
							if($1->loc->type->type!=_BOOL)	
							conv2bool($1); 
							backpatch($1->truelist,$4);
							backpatch($1->falselist,$8);
							backpatch(l,quadPointer);
						}
						;

logical_OR_expression:	logical_AND_expression 									|
						//The || operator handling 
						logical_OR_expression LogOR M logical_AND_expression
						{
							$$ = new expression;
							if($1->loc->type->type!=_BOOL)	//typechecking for bool						
							conv2bool($1);
							if($4->loc->type->type!=_BOOL)
							conv2bool($4);
							backpatch($1->falselist,$3);//backpatching falselist of statement 1
							$$->loc = symTab->gentemp();
							updateSymbol($$->loc,createType(_BOOL));
							$$->type = createType(_BOOL);
							$$->truelist = merge($1->truelist,$4->truelist);//truelist assingment
							$$->falselist = $4->falselist;//falselist assignment
						}
						;

logical_AND_expression:	inclusive_OR_expression 	
						|
						//The AND OP handling. Same as class illustrations
						logical_AND_expression LogAND M inclusive_OR_expression
						{
							$$ = new expression;
							if($1->loc->type->type!=_BOOL)//type checking							
							conv2bool($1);
							if($4->loc->type->type!=_BOOL)
							conv2bool($4);
							backpatch($1->truelist,$3);
							$$->loc = symTab->gentemp();
							updateSymbol($$->loc,createType(_BOOL));//making the type bool
							$$->type = createType(_BOOL);
							$$->truelist = $4->truelist;
							$$->falselist = merge($1->falselist,$4->falselist);
						}
						;

inclusive_OR_expression:exclusive_OR_expression 								|
						inclusive_OR_expression '|' exclusive_OR_expression
						{
							//handled as if it is the binary operator
							$$ = new expression;
							typecheck($1,$3);
							$$->type = $1->type;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->type);
							$$->type = $$->loc->type;
							emit(BIT_OR,($$->loc)->name,($1->loc)->name,($3->loc)->name);
						}
						;

exclusive_OR_expression:AND_expression 											|
						exclusive_OR_expression POWER M AND_expression
						{
							//handled as if both the left and right side are boolean types.
							//Not checked for test case. Will be differently implemented if considered as binary operator
							$$ = new expression;
							backpatch($1->truelist,quadPointer);
							emit(COPY,$1->loc->name,"1");
							emit(_goto,to_string($3));
							backpatch($1->falselist,quadPointer);
							emit(COPY,$1->loc->name,"0");
							emit(_goto,to_string($3));

							$$->truelist = makelist(quadPointer);
							backpatch($4->falselist,quadPointer);
							emit(_if,"---",$1->loc->name);
							$$->falselist = makelist(quadPointer);
							emit(_goto,"---");

							list<int>* temp = makelist(quadPointer);
							$$->falselist = merge($$->falselist,temp);
							backpatch($4->truelist,quadPointer);
							emit(_if,"----",$4->loc->name);
							temp = makelist(quadPointer);
							$$->truelist = merge($$->truelist,temp);
							emit(_goto,"---");						
						}
						;

AND_expression :		equality_expression 									|
						AND_expression BITWISEAND equality_expression
						{
							//handled as if it is the binary operator
							$$ = new expression;
							typecheck($1,$3);
							$$->loc=symTab->gentemp();
							$$->type = $1->type;
							updateSymbol($$->loc,$1->type);
							emit(BIT_AND,($$->loc)->name,($1->loc)->name,($3->loc)->name);
						}
						;

equality_expression:	relational_expression 									
						|
						equality_expression EQUAL relational_expression 			
						{
							//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(EQUAL_TO,$1,$3);
						}
						|
						equality_expression NEQUAL relational_expression
						{
							//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(NOT_EQUAL_TO,$1,$3);
						}
						;

relational_expression:	shift_expression 										|
						relational_expression LESSTHAN shift_expression
						{
							//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(LESS_THAN,$1,$3);
						} 				
						|
						relational_expression GREATERTHAN shift_expression 				
						{	//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(GREATER_THAN,$1,$3);
						}
						|
						relational_expression LTE shift_expression 				
						{//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(LESS_THAN_EQUAL,$1,$3);

						}
						|
						relational_expression GTE shift_expression
						{//relational_expression handling Look at the funciton Definitions for more info.
							$$ = relationEvaluate(GREATER_THAN_EQUAL,$1,$3);
						}
						;

shift_expression:		additive_expression 									|
						shift_expression SHL additive_expression 
						{
							if($3->type->type==_INT)//will only occur if right side expression is of integer type
							{
								//Handled like a binary operator
								$$ = new expression;
								$$->loc=symTab->gentemp();
								updateSymbol($$->loc,$1->type);						
								$$->type = $1->type;
								emit(LEFT_SHIFT,($$->loc)->name,($1->loc)->name,($3->loc)->name);
							}
							else
							{
								cerr<<"Incompatible type"<<endl;
							}
						}			
						|
						shift_expression SHR additive_expression
						{
							if($3->type->type==_INT)
							{
								//same as above
								//Handled like a binary operator
								$$ = new expression;
								$$->loc=symTab->gentemp();
								updateSymbol($$->loc,$1->type);									
								$$->type = $1->type;
								emit(RIGHT_SHIFT,($$->loc)->name,($1->loc)->name,($3->loc)->name);
							}
							else{
								cerr<<"Incompatible type"<<endl;
							}
						};
//The following expressions are of binary type and semantics are self explanatory with adequate typechecking
additive_expression :	multiplicative_expression 								|
						additive_expression PLUSop multiplicative_expression
						{
							
							typecheck($1,$3);
							$$ = new expression;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $1->type;
							emit(PLUS,($$->loc)->name,($1->loc)->name,($3->loc)->name);
						}
						|
						additive_expression MINUSop multiplicative_expression
						{

							typecheck($1,$3);
							$$ = new expression;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $1->type;
							emit(MINUS,($$->loc)->name,($1->loc)->name,($3->loc)->name);
						}
						;

multiplicative_expression:	cast_expression 									|
						multiplicative_expression MUL cast_expression 
						{
							
							typecheck($1,$3);
							$$ = new expression;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $$->loc->type;							
							emit(MULT,($$->loc)->name,($1->loc)->name,($3->loc)->name);	
						}
						|
						multiplicative_expression DIV cast_expression
						{
							
							typecheck($1,$3);
							$$ = new expression;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $$->loc->type;
							emit(DIVIDE,($$->loc)->name,($1->loc)->name,($3->loc)->name);	
						}
						|
						multiplicative_expression PERCENT cast_expression
						{
							
							typecheck($1,$3);
							$$ = new expression;
							$$->loc=symTab->gentemp();
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $$->loc->type;
							emit(MODULUS,($$->loc)->name,($1->loc)->name,($3->loc)->name);
						}
						;

//This is the semantic action which will determine the postion of an array or pointer in left side or right side of the '=' sign
cast_expression : 		unary_expression 
						{
							if($1->array_oc!=0)
							{
								$$ = new expression;
								$$->loc = symTab->gentemp();
								updateSymbol($$->loc,getBaseType($1->type));
								$$->type = getBaseType($1->type);
								emit(ARRAYRIGHT,$$->loc->name,array_name,$1->loc->name);
							}
							else if($1->isPointer==1)
							{
								$$ = new expression;
								$$->loc = symTab->gentemp();
								updateSymbol($$->loc,getBaseType($1->type));
								$$->type = getBaseType($1->type);
								emit(UPOINTER,$$->loc->name,$1->loc->name);
							}
							else
							{
								$$ = $1;
							}
						}
						|
						LPA type_name RPA cast_expression//type casting
						{
							if($4->loc->type->type !=$2->type)
							{
								convert($4,$2->type);
							}
							$$ = $4;
						}
						;
//The unary operators
unary_operator	:		BITWISEAND {
								$$=new opPointer;
								$$->op = UADDRESS;
							}													
							|
						MUL	{
								$$=new opPointer;
								$$->op = UPOINTER;
							}									 				
							|
						PLUSop {
								$$=new opPointer;
								$$->op = UPLUS;
							}													
							|
						MINUSop {
								$$=new opPointer;
								$$->op = UMINUS;
							}													
						

							|
						TILDE {
								$$=new opPointer;
								$$->op = UBITNEGATION;
							}													
							|
						APO {
								$$=new opPointer;
								$$->op = UNEGATION;
							}
						;

unary_expression:		postfix_expression 
						{
							$$ = $1;
						}
						|
						INC unary_expression 	
						{
							emit(PLUS,$2->loc->name,$2->loc->name,to_string(1));															
							$$ = $2;
							$$->loc = $2->loc;
							$$->type = $2->type;
						}
						|
						DEC unary_expression 
						{
							emit(MINUS,$2->loc->name,$2->loc->name,to_string(1));	
							$$ = $2;
							$$->loc = $2->loc;
							$$->type = $2->type;							
						}
						|
						unary_operator cast_expression 	//Case when pointer and address types are distinguished
						{
							if($1->op!=UADDRESS && $1->op!=UPOINTER)
							{
								$$ = new expression;
								$$->loc = symTab->gentemp();
								updateSymbol($$->loc,$2->type);
								emit($1->op,$$->loc->name,$2->loc->name);
								$$->type = $2->type;
							}
							if($1->op==UPOINTER)
							{
									$$ = new expression;
									$$->loc = $2->loc;
									$$->type = $2->loc->type;
									$$->isPointer = 1;//assign that it is the of pointer type
									$$->truelist = 0;
									$$->falselist = 0;
									$$->array_oc = 0;
								

							}
							if($1->op==UADDRESS)
							{
								$$ = new expression;
								$$->loc = symTab->gentemp();
								Type *t = createType(_POINTER);//the temporary will be a pointer type
								t->next = $2->type;
								updateSymbol($$->loc,t);
								$$->type=$$->loc->type;
								emit($1->op,$$->loc->name,$2->loc->name);
							}
						}
						|
						SIZEOF unary_expression 								|
						SIZEOF LPA type_name RPA
						;

argument_expression_list_opt:
						argument_expression_list 
						|
						/*epsilon*/{$$=0;}
						;

argument_expression_list://makes the list of arguments for function handling
						assignment_expression 	
						{
							$$=new arg_list;
							$$->args = makelistArgs($1);
						}
						|
						argument_expression_list COMMA assignment_expression
						{
							$$ = new arg_list;
							list<expression*> *temp = makelistArgs($3);
							mergeArgs($1->args,temp);
							$$->args = $1->args;
						}
						;

postfix_expression :	primary_expression 
						{
							$$ = $1;
							$$->array_oc = 0;//not an array type
						}
						|
						postfix_expression LSB expression RSB //the array expression
						{
							$$ = new expression;							
							if($1->array_oc == 0)//if it is not the array type, i.e. the type is encountered for the first time
							{
								$$->loc = symTab->gentemp();
								Type *baseType = getBaseType($1->loc->type);								
								$$->loc->type = $1->loc->type->next;
								if($$->loc->type->type==_CHAR || $$->loc->type->type==_DOUBLE)
								{
									
									$$->type = createType($$->loc->type->type);
									$$->loc->type = createType(_INT);
								}
								else 
									$$->type = $$->loc->type;
								array_name = $1->loc->name;//store the array name for quad result declaration
								int add_size = $1->loc->type->next->width;
								$$->array_oc = baseType->width;
								emit(MULT,($$->loc->name),$3->loc->name,to_string(add_size));
								//Not that in case of two dimensional array the temporary will contain the type array for future use. This can be easily solved in the final update to symbol table
							}
							else
							{
								$$->loc = symTab->gentemp();
								Type *baseType = getBaseType($1->loc->type);								
								$$->loc->type = $1->loc->type->next;
								if($$->loc->type->type==_CHAR || $$->loc->type->type==_DOUBLE)
								{									
									$$->type = createType($$->loc->type->type);
									$$->loc->type = createType(_INT);
								}
								else 
									$$->type = $$->loc->type;							
								$$->array_oc = baseType->width;
								int add_size = $1->loc->type->next->width;
								Symbol* temp = symTab->gentemp();
								updateSymbol(temp,$$->loc->type);
								//This is the case of multi dimensional array
								emit(MULT,temp->name,$3->loc->name,to_string(add_size));
								emit(PLUS,$$->loc->name,$1->loc->name,temp->name);
							}
						}
						|
						postfix_expression LPA argument_expression_list_opt RPA 
						{
							//the function handling
							$$ = new expression;
							$$->loc = symTab->gentemp();							
							Symbol* ret = $1->loc->symTabPointer->lookup("$return_value$");
							if(ret->type->type!=_VOID)
							{
								$$->loc = symTab->gentemp();
								updateSymbol($$->loc,ret->type);
								$$->type = ret->type;	
							}

							list<expression*> *L = new list<expression*>;
							L = $3?$3->args:0;//The arguments list
							int number_of_args;
							if(L)
							{
								number_of_args =  $3->args->size();
							} 
							else
							{
								number_of_args = 0;
							}
							int number_of_params = $1->loc->symTabPointer->param;

							if(number_of_params>number_of_args)//parameter count checking
							{
								cerr<<"TOO LESS ARGUMENTS"<<endl;
							}
							else if(number_of_params<number_of_args)
							{
								cerr<<"TOO MANY ARGUMENTS"<<endl;
							}
							else
							{	//One can do parameter type checking but for the sake of ease of complexity it is avoided
								if($3)
								{
									L = $3->args;
									for(list<expression*>::iterator it = (*L).begin();it != (*L).end(); ++it)
									{
										expression* index = *it;
										emit(PARAM,index->loc->name);//printing quads of parameters
									}
									if(ret->type->type!=_VOID)
									emit(CALL,$$->loc->name,$1->loc->name,to_string(number_of_params));//caslling the funciton
									else
									emit(CALL,"VOID",$1->loc->name,to_string(number_of_params));//caslling the funciton
								}
								else
								{	
									if(ret->type->type!=_VOID)
									emit(CALL,$$->loc->name,$1->loc->name,to_string(number_of_params));
									else
									emit(CALL,"VOID",$1->loc->name,to_string(number_of_params));//caslling the funciton
								}
							}
							
						}
						|
						postfix_expression FULLSTOP IDENTIFIER 						
						|
						postfix_expression ACC IDENTIFIER
						|
						postfix_expression INC 	
						{							
							$$ = new expression;
							$$->loc = symTab->gentemp();													
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $$->loc->type;							
							emit(COPY,$$->loc->name,$1->loc->name);
							emit(PLUS,$1->loc->name,$1->loc->name,"1");	
						}
						|
						postfix_expression DEC 
						{
							$$ = new expression;
							$$->loc = symTab->gentemp();														
							updateSymbol($$->loc,$1->loc->type);
							$$->type = $$->loc->type;
							emit(COPY,$$->loc->name,$1->loc->name);
							emit(MINUS,$1->loc->name,$1->loc->name,"1");
						}
						|
						LPA type_name RPA LCB initializer_list RCB 				|
						LPA type_name RPA LCB initializer_list COMMA RCB
						;

primary_expression:		IDENTIFIER //Symbol pointer type hence a new expression is declared to point to that symbol location
						{
							$$ = new expression;
							$$->loc = $1;
							$$->type = $$->loc->type;
							$$->truelist = 0;
							$$->falselist = 0;
						}												
						|
						constant 	{$$ = $1;}											
						|
						STRING_LITERAL 	
						{
							$$ = new expression;
							$$->loc = symTab->gentemp();
							Type *t = createType(_POINTER);
							t->next = createType(_CHAR);
							updateSymbol($$->loc,t);
							$$->type = t;
							emit(_STRING,$$->loc->name,$1,"NULL");
						}	//avoided		
						|
						LPA expression RPA{$$ = $2;}
						;

constant :				INTEGER_CONSTANT 
						{
							$$ = new expression;
							$$->loc=symTab->gentemp();
							$$->type = createType(_INT);
							updateSymbol($$->loc,$$->type);
							$$->int_val = $1;//assingment of integer value. Useful for array declaration and width calculations
							updateSymbolInitVal($$->loc,to_string($1));
							emit(COPY,$$->loc->name,to_string($1));		
							$$->truelist = 0;
							$$->falselist = 0;					
						}
						|
						FLOATING_CONSTANT
						{
							$$ = new expression;
							$$->loc=symTab->gentemp();
							$$->type = createType(_DOUBLE);
							updateSymbol($$->loc,$$->type);
							updateSymbolInitVal($$->loc,to_string($1));
							emit(COPY,$$->loc->name,to_string($1));
							$$->double_val = $1;
							$$->int_val=-1;//when we have wrong integer type will throw an error in case of array width
							$$->truelist = 0;
							$$->falselist = 0;	
						}
						|
						CHARACTER_CONSTANT
						{
							$$ = new expression;
							$$->loc=symTab->gentemp();
							$$->type = createType(_CHAR);
							updateSymbol($$->loc,$$->type);
							updateSymbolInitVal($$->loc,to_string($1));
							emit(COPY,$$->loc->name,to_string($1));
							$$->char_val = to_string($1);
							$$->int_val = -1;//when we have wrong integer type will throw error in case of array width
						}
						;						

enumeration_constant:	IDENTIFIER
						;						
	
//The augmented non terminals.						
M :						{
							$$=quadPointer;//contain the value of next quad pointer
						}
						;
N :						{
							$$ = new expression;
							$$->nextlist=makelist(quadPointer);//emit a dangling goto
							emit(_goto,"---");	
						}
							
%%
//in case of error.
void yyerror(const char* s){
    printf("%s",s);
}
