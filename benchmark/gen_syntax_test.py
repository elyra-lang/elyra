import random
import argparse
import string
import sys

# (The TOKENS list is still defined for reference,
# but note that we no longer output random tokens.)
TOKENS = [
    "(", ")", "{", "}", "[", "]", ";", ".", ",", "?", "!", ":", "+", "+=", "+|", "+|=", "+%", "+%=",
    "-", "-=", "-|", "-|=", "-%", "-%=", "*", "*=", "*|", "*|=", "*%", "*%=", "/", "/=", "<", "<=", ">", ">=",
    "==", "=>", "!=", "=", "&", "&=", "|", "|=", "<<", "<<=", "<<|", "<<|=", ">>", ">>=", "^", "^=", "~", "%", "%=",
    "->", "and", "or", "not", "let", "var", "func", "return", "match", "if", "else", "trait", "struct", "import",
    "while", "break", "continue", "for", "temp", "pub", "true", "false", "null"
]

WHITESPACE = [" ", "\n", "\t"]
IDENTIFIER_CHARS = string.ascii_letters + string.digits + "_"


def generate_identifier():
    length = random.randint(3, 8)  # Identifier length between 3-8 characters
    # Ensure the first character is a letter or underscore
    return "".join(random.choices(string.ascii_letters + "_", k=1)) + "".join(random.choices(IDENTIFIER_CHARS, k=length - 1))


def generate_literal():
    choice = random.choice(["boolean", "integer", "float", "string", "char"])
    if choice == "boolean":
        return random.choice(["true", "false"])
    elif choice == "integer":
        return str(random.randint(0, 10000))
    elif choice == "float":
        return f"{random.uniform(0, 10000):.2f}"
    elif choice == "string":
        length = random.randint(3, 10)
        return f'"{"".join(random.choices(string.ascii_letters, k=length))}"'
    elif choice == "char":
        return f"'{random.choice(string.ascii_letters)}'"


def generate_binary_expression():
    """
    Generates a binary expression of the form:
        operand operator operand
    where each operand is either an identifier or a literal and the operator
    is chosen from a list of common binary operators.
    """
    left = random.choice([generate_identifier(), generate_literal()])
    right = random.choice([generate_identifier(), generate_literal()])
    binary_ops = ["+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">=", "and", "or"]
    op = random.choice(binary_ops)
    return f"{left} {op} {right}"


def generate_statement():
    """
    Generates an assignment statement. With a 50% chance,
    the assigned value is a binary expression.
    Otherwise, it is a simple identifier or literal.
    """
    assignment_type = random.choice(["let", "var", ""])  # Optionally include a keyword
    variable = generate_identifier()
    # 50% chance to use a binary expression
    if random.random() < 0.5:
        value = generate_binary_expression()
    else:
        value = random.choice([generate_identifier(), generate_literal()])
    if assignment_type:
        return f"{assignment_type} {variable} = {value};"
    else:
        return f"{variable} = {value};"


def generate_function():
    """
    Generates a function definition with a random name, parameters,
    a few statements, and a return value.
    """
    func_name = generate_identifier()
    param_count = random.randint(1, 4)
    params = ", ".join(f"{generate_identifier()}: {generate_identifier()}" for _ in range(param_count))
    return_type = generate_identifier()
    num_statements = random.randint(1, 5)
    statements = "\n".join("    " + generate_statement() for _ in range(num_statements))
    return (
        f"let {func_name} = func ({params}) -> {return_type} {{\n"
        f"{statements}\n"
        f"    return {random.choice([generate_identifier(), generate_literal()])};\n"
        f"}}"
    )


def generate_comment():
    """
    Generates a single-line comment with random text.
    """
    word_count = random.randint(3, 10)
    words = []
    for _ in range(word_count):
        word_length = random.randint(3, 8)
        word = "".join(random.choices(string.ascii_lowercase, k=word_length))
        words.append(word)
    comment_text = " ".join(words)
    return f"# {comment_text}"


def generate_random_line():
    """
    Randomly selects one of the generator functions to produce a code element.
    Note: We have removed the option to insert random tokens.
    """
    choice = random.choice(["statement", "function", "comment"])
    if choice == "statement":
        return generate_statement()
    elif choice == "function":
        return generate_function()
    elif choice == "comment":
        return generate_comment()


def generate_elyra_code(num_lines, output_file="test.ely"):
    """
    Generates Elyra code ensuring the final output file contains exactly num_lines lines.
    If a generated element spans multiple lines, each line is counted.
    """
    with open(output_file, "w", encoding="utf-8") as f:
        written_lines = 0
        while written_lines < num_lines:
            element = generate_random_line()
            # Split multiline elements into individual lines
            lines = element.splitlines()
            for line in lines:
                if written_lines < num_lines:
                    f.write(line + "\n")
                    written_lines += 1
                else:
                    break
            # Print progress at every 1% (or every line for small files)
            if written_lines % max(1, num_lines // 100) == 0:
                progress = (written_lines * 100) // num_lines
                sys.stdout.write(f"\rProgress: {progress}%")
                sys.stdout.flush()
    print("\nElyra code generation complete!")


def main():
    parser = argparse.ArgumentParser(description="Generate valid Elyra code")
    parser.add_argument("-l", "--lines", type=int, default=262144, help="Number of lines of Elyra code to generate")
    parser.add_argument("-o", "--output", type=str, default="test.ely", help="Output file name")

    args = parser.parse_args()

    print(f"Generating {args.lines} lines of Elyra code...")
    generate_elyra_code(args.lines, args.output)

    print(f"Elyra code written to {args.output}")


if __name__ == "__main__":
    main()
