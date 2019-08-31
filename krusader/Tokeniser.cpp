/*
	Usage: Tokeniser [-C] source.asm output.bin
	Use the -C option to produce binary output compatible with the 65C02 version of the assembler
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define LINE_SIZE 36
#define ARG_SIZE 13
#define LABEL_SIZE 6
#define COMMENT_START 30

#define EOL 0
#define EOFLD 1
#define BLANK 2

#define FALSE 0
#define TRUE 1

#define FAIL 0xFF

void doGenericFormat();

char *getLine(char *line);
int getLabel(char *line, char *label);
int handleMnemonic(char *line, int start, int *code);
int get6502MNEIndex(char *line, int start);
int get65C02MNEIndex(char *line, int start);
int getArgs(char *line, int start, char *args);

void doEOL(char *label, int mneCode, char *args);
void doError(char *message, char *line);

int whitespace(char c);
int skipSpaces(int start, char *line);

FILE *in = NULL;
FILE *out = NULL;

int do65C02 = 0;

int main(int argc, char* argv[])
{
  int i = 1;

  switch (argc)
  {
    case 3:
      do65C02 = 0;
      break;
    case 4:
      if (!strcmp(argv[1], "-C"))
      {
        do65C02 = 1;
        i++;
        break;
      }
    default:
      fprintf(stderr, "Usage: tokenise [-C] inputFile outputFile\n");
      exit(1);
  }

  in = fopen(argv[i], "r");
  if (!in)
  {
    fprintf(stderr, "Can't open input file %s\n", in);
    exit(1);
  }

  out = fopen(argv[i + 1], "wb");
  if (!out)
  {
    fprintf(stderr, "Can't open output file %s!\n", argv[i + 1]);
    exit(1);
  }

  doGenericFormat();

  fclose(in);
  fclose(out);

  return 0;
}

/*
  Semicolon at any position indicates a comment
  Entry in column 1 is a label - truncate to 6 chars if necessary
  Interpret a label on its own line as .M
  First entry after a space is a mnemonic or directive
    (try some simple directives mapping - byte and db to B
                                          word and dw to W
                                          ascii, str and ds to S
                                          equ to =
                                          org to .M $nnnn)
  Arguments follow the space after the mnemonic, and end at next space or EOL
  Any text following arguments is ignored (i.e. comments are not translated in generic mode)
*/
void doGenericFormat()
{
  int i;

  char line[LINE_SIZE] = {0};
  while (getLine(line))
  {
    char label[LABEL_SIZE + 1] = {0};
    char args[ARG_SIZE + 1] = {0};
    int mneCode = 0;
    int savePos = 0;

    //printf("\n%s", line);

    // check for blanks

    if (strlen(line) == 0)
    {
      fputc(BLANK, out);
      fputc(EOL, out);
      continue; // go to the next line
    }

    i = 0;
    if (!whitespace(line[i]))
    {
      i = getLabel(line, label);
      if (i < 0) doError("Problem with label", line);
    }
    i = skipSpaces(i, line);
    if (i < 0)
    {
      int j, k = (int)strlen(label);
      if (k > 0)  /* we have a label but no mnemonic - make it a module */
      {
        for (j = 0; j < k; ++j)
          fputc(label[j], out);
        fputc(EOFLD, out);
        fputc(('M' << (do65C02 ? 1 : 0)) + 1, out);
        fputc(EOL, out);
        continue;
      }
      if (i < 0) doError("Problem with line", line);
    }

    i = handleMnemonic(line, i, &mneCode);
    savePos = i;
    i = skipSpaces(i, line);
    /* need to make sure comments dont get confused as arguments */
    /* so check we are not past the comment start position,
      and also, don't allow more than 8 spaces between the mnemonic
      and the following argument */
    if (i > 0 && line[i] != ';' && i < COMMENT_START && (i - savePos < 8))
      getArgs(line, i, args);
    doEOL(label, mneCode, args);
  }

  fputc(EOL, out);
}

void doEOL(char *label, int mneCode, char *args)
{
  int j;
  int k = (int)strlen(label);
  int m = (int)strlen(args);

  if (k > 0)  /* we have a label */
  {
    for (j = 0; j < k; ++j)
      fputc(label[j], out);
  }
  fputc(EOFLD, out);
  fputc(mneCode, out);
  if (m > 0)  /* we have args */
  {
    for (j = 0; j < m; ++j)
      fputc(args[j], out);
  }
  fputc(EOL, out);
}

char *getLine(char *line)
{
  /* get the line, convert tabs to spaces,
    and make sure there is at least one
    non-whitespace character */
  int i, j = 0, k;
  int blank = 1;

  char raw[4 * LINE_SIZE] = {0};

  for (i = 0; i < LINE_SIZE; ++i)
    line[i] = '\0';

  if (fgets(raw, 4 * LINE_SIZE, in))
  {
    for (i = 0; i < (int)strlen(raw), j < LINE_SIZE - 1; ++i)
    {
      char rawch = raw[i];
      if (rawch == '\000' || rawch == ';')
        break;
      else if (rawch == '\t')
      {
        for (k = 0; k < 4; ++k)
          line[j++] = ' ';
      }
      else
      {
        line[j++] = rawch;
        if (!whitespace(rawch))
          blank = 0;
      }
    }

    if (blank == 1)
      line[0] = '\0';

    return line;
  }
  else
    return NULL;
}

int handleMnemonic(char *line, int start, int *code)
{
  if (line[start] == '.')
  {
    start++;
    *code = (int)line[start];
    *code = (*code << (do65C02 ? 1 : 0)) + 1;
    return ++start;
  }
  else if (line[start] == '=')
  {
    start++;
    *code = ('=' << (do65C02 ? 1 : 0)) + 1;
    return start;
  }
  else
  {
    *code = do65C02 ? get65C02MNEIndex(line, start) + 1 :
      get6502MNEIndex(line, start) + 1;
    return start + 3;
  }
}

int get6502MNEIndex(char *line, int start)
{
  static char *mnemonics[] =
    {"PHP","CLC","PLP","SEC","PHA","CLI","PLA","SEI","DEY","TYA","TAY","CLV","INY",
    "CLD","INX","SED","TXA","TXS","TAX","TSX","DEX","NOP","BRK","RTI","RTS",
    "BPL","BMI","BVC","BVS","BCC","BCS","BNE","BEQ","JSR","BIT","JMP","STY",
    "LDY","CPY","CPX","ORA","AND","EOR","ADC","STA","LDA","CMP","SBC","ASL",
    "ROL","LSR","ROR","STX","LDX","DEC","INC"};
  static int numMnemonics = 56;

  int i;
  char *mne = &line[start];

  for (i = 0; i < numMnemonics; ++i)
  {
    if (toupper(mne[0]) == mnemonics[i][0] &&
      toupper(mne[1]) == mnemonics[i][1] &&
      toupper(mne[2]) == mnemonics[i][2])
      return i;
  }

  return FAIL;
}

int get65C02MNEIndex(char *line, int start)
{
  static char *mnemonics[] =
  {
  "PHP", "CLC", "PLP", "SEC", "PHA", "CLI", "PLA", "SEI", "DEY",
  "TYA", "TAY", "CLV", "INY", "CLD", "INX", "SED", "BRK", "INA",
  "JSR", "DEA", "RTI", "PHY", "RTS", "PLY", "TXA", "TXS", "TAX",
  "TSX", "DEX", "PHX", "NOP", "PLX", "TSB", "TRB", "BIT", "STZ",
  "STY", "LDY", "CPY", "CPX", "ORA", "AND", "EOR", "ADC", "STA",
  "LDA", "CMP", "SBC", "ASL", "ROL", "LSR", "ROR", "STX", "LDX",
  "DEC", "INC", "JMP", "BPL", "BMI", "BVC", "BVS", "BCC", "BCS",
  "BNE", "BEQ", "BRA"
  };
  static int numMnemonics = 66;

  int i;
  char *mne = &line[start];

  for (i = 0; i < numMnemonics; ++i)
  {
    if (toupper(mne[0]) == mnemonics[i][0] &&
      toupper(mne[1]) == mnemonics[i][1] &&
      toupper(mne[2]) == mnemonics[i][2])
      return i;
  }

  return FAIL;
}

int getLabel(char *line, char *label)
{
  int i = 0;

  while (i < LABEL_SIZE)
  {
    char c = line[i];
    if (whitespace(c))
      return i;
    label[i++] = toupper(c);
  }
  while (!whitespace(line[i])) /* skip any extra characters */
  {
    if (++i > LINE_SIZE)
      return -1;
  }

  return i;
}

int getArgs(char *line, int start, char *args)
{
  int k = start;
  int i = 0;

  while (k < LINE_SIZE)
  {
    char c = line[k];
    if (whitespace(c))
      return k;
    args[i++] = toupper(c);
    if (i == ARG_SIZE)
      return k;
    ++k;
  }

  doError("Args error", line);
  return -1;
}

void doError(char *message, char *line)
{
  printf("Error handling line: %s\n", line);
  printf("%s\n", message);
}

int skipSpaces(int start, char *line)
{
  int k;

  for (k = start; k < LINE_SIZE; ++k)
  {
    if (line[k] == '\n' || line[k] == '\r' || line[k] == EOL || line[k] == ';')
      return -1;
    else if (!whitespace(line[k]))
      return k;
  }

  return -1;
}

int whitespace(char c)
{
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}
