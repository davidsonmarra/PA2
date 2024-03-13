/*
 *  A definição do scanner para COOL.
 */

/*
 *  As coisas contidas em %{ %} na primeira seção são copiadas textualmente para
 *  a saída, então cabeçalhos e definições globais são colocadas aqui para serem visíveis
 *  para o código no arquivo. Não remova nada que estava aqui inicialmente.
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* O compilador assume esses identificadores. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Tamanho máximo das constantes de string */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* mantém o g++ feliz */

extern FILE fin; / lemos deste arquivo */

/* define YY_INPUT para que lemos do arquivo fin:
 * Essa mudança torna possível usar este scanner no
 * compilador COOL.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
    if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
        YY_FATAL_ERROR( "read() no scanner flex falhou");

char string_buf[MAX_STR_CONST]; /* para montar constantes de string */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Adicione suas próprias definições aqui
 */

// declarações de função
bool add_character_to_string_buffer(char);
int string_too_long();

// a seguinte macro tenta adicionar o caractere dado ao buffer de string. Se a string ficar muito longa, ela chama uma função para lidar com isso apropriadamente
#define ADD_CHAR(c) if(!add_character_to_string_buffer( (c) )) return string_too_long()

// inteiro para manter a profundidade de comentários aninhados
int comment_depth=0;
%}

/*
 * Defina nomes para expressões regulares aqui.
 */

DARROW          =>
LE              <=
ASSIGN          <-
LETTER          [a-zA-Z]
DIGIT           [0-9]
ULETTER         [A-Z]
LLETTER         [a-z]
WHITESPACE      [ \n\f\r\t\v]
TYPEID          {ULETTER}({LETTER}|{DIGIT}|_)*
OBJECTID        {LLETTER}({LETTER}|{DIGIT}|_)*

%x COMMENT STRING IGNORE_STRING
%%

 /*
  *  Comentários aninhados
  */

--.*    {   /comentário de uma linha/ }
"*)"    {
        cool_yylval.error_msg="*) não emparelhado";    // *) fora de qualquer bloco de comentário
        return (ERROR);
        }
"(*"    {
        BEGIN(COMMENT);    //comentário começa
        comment_depth=1;    //Nota: comment_depth++ na verdade causa problemas quando há vários arquivos, já que o contador não é redefinido por padrão
        }
<COMMENT>"(*"    {
                comment_depth++;
                }
<COMMENT>"*)"    {
                comment_depth--;
                if(!comment_depth)
                    BEGIN(INITIAL);    //comentários terminam
                }
<COMMENT>\n        { curr_lineno++; }
<COMMENT>. {   /ignorar texto dentro de comentários/ }
<COMMENT><<EOF>>    {
                    BEGIN(INITIAL);    //para sair com erro
                    cool_yylval.error_msg="EOF no comentário";
                    return (ERROR);
                    }


 /*
  *  Os operadores de vários caracteres.
  */
{DARROW}        { return (DARROW); }
{LE}            { return (LE); }
{ASSIGN}        { return (ASSIGN); }

 /*
  * Palavras-chave não diferenciam maiúsculas de minúsculas, exceto pelos valores true e false,
  * que devem começar com uma letra minúscula.
  */
[iI][fF]    {return (IF); }
[tT][hH][eE][nN]    {return {THEN};}
[eE][lL][sS][eE]    {return (ELSE);}
[fF][iI]    { return (FI); }

[wW][hH][iI][lL][eE]    { return (WHILE); }
[lL][oO][oO][pP]    { return (LOOP); }
[pP][oO][oO][lL]    { return (POOL); }

[lL][eE][tT]    { return (LET); }
[iI][nN]    { return (IN); }

[cC][aA][sS][eE]    { return (CASE); }
[oO][fF]    { return (OF); }
[eE][sS][aA][cC]    { return (ESAC); }

[nN][eE][wW]    { return (NEW); }

[iI][sS][vV][oO][iI][dD]    { return (ISVOID); }

[nN][oO][tT]    { return (NOT); }

[cC][lL][aA][sS][sS]    { return (CLASS); }
[iI][nN][hH][eE][rR][iI][tT][sS]    { return (INHERITS); }

t[rR][uU][eE]    { cool_yylval.boolean=true; return (BOOL_CONST); }
f[aA][lL][sS][eE]    { cool_yylval.boolean=false; return (BOOL_CONST); }

 /*
  *  TypeID e ObjectID. TypeID deve começar com uma letra maiúscula, enquanto ObjectID deve começar com uma letra minúscula.
  */

{TYPEID}    {
            cool_yylval.symbol=idtable.add_string(yytext);    //adiciona a string à tabela de IDs
            return (TYPEID);
            }
{OBJECTID}    {
            cool_yylval.symbol=idtable.add_string(yytext);    //adiciona a string à tabela de IDs
            return (OBJECTID);
            }

 /*
  * Constantes inteiras consistem em strings de um ou mais dígitos contínuos.
  */
{DIGIT}+    {
            cool_yylval.symbol=inttable.add_string(yytext);    //adiciona a string à tabela de INTs
            return (INT_CONST);
            }

 /*
  *  Constantes de string (sintaxe C)
  *  A sequência de escape \c é aceita para todos os caracteres c. Exceto por
  *  \n \t \b \f, o resultado é c.
  *
  */
\"    {
    BEGIN(STRING);    //string começa
    string_buf_ptr=string_buf;    //define o ponteiro do buffer para o início do buffer
    }
<STRING>\"    {    //fim da constante de string
            if(string_buf_ptr-string_buf>=MAX_STR_CONST)
                {
                cool_yylval.error_msg="Constante de string muito longa";
                BEGIN(INITIAL);
                return (ERROR);
                }
            *string_buf_ptr='\0';    //termina a string formada
            cool_yylval.symbol=stringtable.add_string(string_buf);    //adiciona a string à tabela de STRING
            BEGIN(INITIAL);    //fim do estado da string
            return (STR_CONST);
            }
<STRING>\n    {    //nova linha dentro de uma string
            cool_yylval.error_msg="Constante de string não terminada";
            curr_lineno++;    //incrementa o número da linha
            BEGIN(INITIAL);    //fim do estado da string, supondo que o programador esqueceu de terminar a string
            return (ERROR);
            }
<STRING>\\n    {    //n escapado para significar nova linha
            ADD_CHAR('\n');
            }
<STRING>\\t    {    //t escapado para significar tabulação horizontal
            ADD_CHAR('\t');
            }
<STRING>\\b    {    //b escapado para significar retrocesso
            ADD_CHAR('\b');
            }
<STRING>\\f    {    //f escapado para significar avanço de página
            ADD_CHAR('\f');
            }
<STRING>\\\n    {    //nova linha escapada
                curr_lineno++;    //incrementa o número da linha
                ADD_CHAR('\n');
                }
<STRING>\\\0    {
                BEGIN(IGNORE_STRING);    //ignorar o restante da string
                cool_yylval.error_msg="String contém caractere nulo escapado.";
                return (ERROR);
                }
<STRING>\\(.|\n)    {    //qualquer caractere escapado
                ADD_CHAR(yytext[1]);    //ignora a barra invertida e adiciona o caractere depois disso. Nota - O caso especial de nova linha escapada já foi tratado acima
                }
<STRING>\0    {    //caractere nulo
            BEGIN(IGNORE_STRING);    //ignorar o restante da string
            cool_yylval.error_msg="String contém caractere nulo.";
            return (ERROR);
            }
<STRING><<EOF>>    {
                BEGIN(INITIAL);    //para sair graciosamente
                cool_yylval.error_msg="EOF na constante de string";
                return (ERROR);
                }
                
<STRING>.    {    //para cada caractere (exceto \n, é claro). Nota - O caso especial de \n foi tratado acima.
            ADD_CHAR(yytext[0]);//pega o primeiro (e único) caractere
            }

 /*
  * Ignorar caracteres da string em caso de string longa ou caractere inválido
  */
<IGNORE_STRING>\n    { curr_lineno++; BEGIN(INITIAL); }
<IGNORE_STRING>\\\n    { curr_lineno++; /* nova linha escapada */ }
<IGNORE_STRING>\\\"    { /* Ignorar aspas escapadas */ }
<IGNORE_STRING>\\\\    { /* Ignorar barra invertida escapada */ }
<IGNORE_STRING>\"    { BEGIN(INITIAL); }
<IGNORE_STRING>.    { /* Qualquer outro caractere */ }

 /*
  * Contagem do número da linha
  */
\n    { curr_lineno++; }
 /*
  *  Caracteres de espaço em branco
  */
{WHITESPACE}    { /* Ignorar todos os espaços em branco. Note que adicionar '*' no final faria com que não contássemos as linhas */ }

 /*
  * Caracteres únicos permitidos
  */
[-+*/~<=(){};:,.@]    {    //retorna o caractere único
                    return yytext[0];
                    }
.    {    //todos os outros caracteres
    cool_yylval.error_msg=yytext;
    return (ERROR);
    }
    
%%

/*
 * Esta função adiciona o literal do caractere dado ao buffer de string.
 * Então, verifica se a string excedeu o comprimento máximo. Se sim, retorna falso. Caso contrário, retorna verdadeiro.
 */
bool add_character_to_string_buffer(char c) {
    if(string_buf_ptr-string_buf>=MAX_STR_CONST)
        return false;
    *string_buf_ptr++=c;
    return true;
}

/*
 * Esta função define a flag de erro como "Constante de string muito longa" e vai para o estado IGNORE_STRING para pular os caracteres restantes
 */
int string_too_long() {
    cool_yylval.error_msg="Constante de string muito longa";
    BEGIN(IGNORE_STRING);
    return (ERROR);
}