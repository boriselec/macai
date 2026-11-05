//
//  MessageParser.swift
//  macaiTests
//
//  Created by Renat Notfullin on 25.04.2023.
//

import XCTest
@testable import macai

class MessageParserTests: XCTestCase {

    var parser: MessageParser!

    override func setUp() {
        super.setUp()
        parser = MessageParser(colorScheme: .light)
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }


    /*
     Test generic message with table
     */
    func testParseMessageFromStringGeneric() {
        let input = """
        This is a sample text.

        Table: Test Table
        | Column 1 | Column 2 |
        | -------- | -------- |
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |

        This is another sample text.
        """

        let result = parser.parseMessageFromString(input: input)
        XCTAssertEqual(result.count, 3)

        switch result[0] {
        case .text(let text):
            XCTAssertEqual(text, """
            This is a sample text.
            
            Table: Test Table
            """)
        default:
            XCTFail("Expected .text element")
        }

        switch result[1] {
        case .table(header: let header, data: let data):
            XCTAssertEqual(header, ["Column 1", "Column 2"])
            XCTAssertEqual(data, [["Value 1", "Value 2"], ["Value 3", "Value 4"]])
        default:
            XCTFail("Expected .table element")
        }

        switch result[2] {
        case .text(let text):
            XCTAssertEqual(text, "This is another sample text.")
        default:
            XCTFail("Expected .text element")
        }
    }
    
    /*
     Test incomplete message in response
     https://github.com/Renset/macai/issues/15
     */
    func testParseMessageFromStringGitHubIssue15() {
        let input = """
        Here's a FizzBuzz implementation in Shakespeare Programming Language:

        ```
        The Infamous FizzBuzz Program.
        By ChatGPT.

        Act 1: The Setup
        Scene 1: Initializing Variables.
        [Enter Romeo and Juliet]
        """
        
        let result = parser.parseMessageFromString(input: input)
        XCTAssertEqual(result.count, 2)

        switch result[0] {
        case .text(let text):
            XCTAssertEqual(text, "Here's a FizzBuzz implementation in Shakespeare Programming Language:\n")
        default:
            XCTFail("Expected .text element")
        }
        
        switch result[1] {
        case .code(code: let highlightedCode):
            XCTAssertEqual(String(highlightedCode.code), """
            The Infamous FizzBuzz Program.
            By ChatGPT.
            
            Act 1: The Setup
            Scene 1: Initializing Variables.
            [Enter Romeo and Juliet]
            """)
        default:
            XCTFail("Expected .code element")
        }
    }
    
    /*
     Test message with the mix of tables and code blocks
     */
    func testParseMessageFromStringTableAndCode() {
        let input = """
        Table: Test Table
        | Column 1 | Column 2 |
        | -------- | -------- |
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |

        ```
        This is a code block
        ```

        **Table 2: Test Table
        | Column 1 | Column 2 |
        | -------- | -------- |
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |
        
        **Table 3: Test Table
        | Column 1 | Column 2 |
        | -------- | -------- |
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |
        
        Some random text. Bla-bla-bla...
        
        **Table 4: Test Table
        | Column 1 | Column 2 |
        | -------- | -------- |
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |
        
        """

        let result = parser.parseMessageFromString(input: input)
        XCTAssertEqual(result.count, 11)

        switch result[1] {
        case .table(header: let header, data: let data):
            XCTAssertEqual(header, ["Column 1", "Column 2"])
            XCTAssertEqual(data, [["Value 1", "Value 2"], ["Value 3", "Value 4"]])
        default:
            XCTFail("Expected .table element")
        }

        switch result[3] {
        case .code(code: let highlightedCode):
            XCTAssertEqual(String(highlightedCode.code), """
            This is a code block
            """)
        default:
            XCTFail("Expected .code element")
        }

        switch result[5] {
        case .table(header: let header, data: let data):
            XCTAssertEqual(header, ["Column 1", "Column 2"])
            XCTAssertEqual(data, [["Value 1", "Value 2"], ["Value 3", "Value 4"]])
        default:
            XCTFail("Expected .table element")
        }
        
        switch result[7] {
        case .table(header: let header, data: let data):
            XCTAssertEqual(header, ["Column 1", "Column 2"])
            XCTAssertEqual(data, [["Value 1", "Value 2"], ["Value 3", "Value 4"]])
        default:
            XCTFail("Expected .table element")
        }
        
        switch result[8] {
        case .text(let text):
            XCTAssertEqual(text, """
            Some random text. Bla-bla-bla...

            **Table 4: Test Table
            """)
        default:
            XCTFail("Expected .text element")
        }
        
        switch result[9] {
        case .table(header: let header, data: let data):
            XCTAssertEqual(header, ["Column 1", "Column 2"])
            XCTAssertEqual(data, [["Value 1", "Value 2"], ["Value 3", "Value 4"]])
        default:
            XCTFail("Expected .table element")
        }
    }
    
    func testParseMessageFromStringMathEquation() {
        let input = """
        Sure, here’s a complex formula from the field of string theory, specifically the action for the bosonic string:

        \\[
        S = -\\frac{1}{4\\pi\\alpha'} \\int d\\tau \\, d\\sigma \\, \\sqrt{-h} \\left( h^{ab} \\partial_a X^\\mu \\partial_b X_\\mu + \\alpha' R^{(2)} \\Phi(X) \\right)
        \\]

        Where:
        - \\( S \\) is the action.
        - \\( \\alpha' \\) is the string tension parameter.
        - \\( \\tau \\) and \\( \\sigma \\) are the worldsheet coordinates.
        - \\( h \\) is the determinant of the worldsheet metric \\( h_{ab} \\).
        - \\( h^{ab} \\) is the inverse of the worldsheet metric.
        - \\( \\partial_a \\) denotes partial differentiation with respect to the worldsheet coordinates.
        - \\( X^\\mu \\) are the target space coordinates of the string.
        - \\( R^{(2)} \\) is the Ricci scalar of the worldsheet.
        - \\( \\Phi(X) \\) is the dilaton field.
        """

        let result = parser.parseMessageFromString(input: input)
        XCTAssertEqual(result.count, 3)
        
        switch result[0] {
        case .text(let text):
            XCTAssertEqual(text, """
            Sure, here’s a complex formula from the field of string theory, specifically the action for the bosonic string:

            """)
        default:
            XCTFail("Expected .text element")
        }
        
        switch result[1] {
        case .formula(let formula):
            XCTAssertEqual(formula, "S = -\\frac{1}{4\\pi\\alpha'} \\int d\\tau \\, d\\sigma \\, \\sqrt{-h} \\left( h^{ab} \\partial_a X^\\mu \\partial_b X_\\mu + \\alpha' R^{(2)} \\Phi(X) \\right)")
        default:
            XCTFail("Expected .formula element")
        }
        
        switch result[2] {
        case .text(let text):
            XCTAssertEqual(text, """
            Where:
            - \\( S \\) is the action.
            - \\( \\alpha' \\) is the string tension parameter.
            - \\( \\tau \\) and \\( \\sigma \\) are the worldsheet coordinates.
            - \\( h \\) is the determinant of the worldsheet metric \\( h_{ab} \\).
            - \\( h^{ab} \\) is the inverse of the worldsheet metric.
            - \\( \\partial_a \\) denotes partial differentiation with respect to the worldsheet coordinates.
            - \\( X^\\mu \\) are the target space coordinates of the string.
            - \\( R^{(2)} \\) is the Ricci scalar of the worldsheet.
            - \\( \\Phi(X) \\) is the dilaton field.
            """)
        default:
            XCTFail("Expected .text element")
        }
        
    }

    /*
     $$...$$ display math as emitted by Gemini, including indented lines inside list items
     */
    func testParseMessageFromStringSingleLineDollarFormulas() {
        let input = """
        To derive the quadratic formula, solve for $x$ by completing the square. (Assume $a \\neq 0$).

        **1. Start with the standard form:**
        $$ax^2 + bx + c = 0$$
        $$ax^2 + bx = -c$$

        *   **Step 2: Swap $a$ and $d$, negate $b$ and $c$**
            $$\\begin{pmatrix} 6 & -7 \\\\ -2 & 4 \\end{pmatrix}$$
        $$P(+) = 0.0095 + 0.0495 = 0.059 \\text{ (5.9%)}$$
        """

        let result = parser.parseMessageFromString(input: input).map(describe)
        XCTAssertEqual(result, [
            "text: To derive the quadratic formula, solve for $x$ by completing the square. (Assume $a \\neq 0$).\n\n**1. Start with the standard form:**",
            "formula: ax^2 + bx + c = 0",
            "formula: ax^2 + bx = -c",
            "text: *   **Step 2: Swap $a$ and $d$, negate $b$ and $c$**",
            "formula: \\begin{pmatrix} 6 & -7 \\\\ -2 & 4 \\end{pmatrix}",
            "formula: P(+) = 0.0095 + 0.0495 = 0.059 \\text{ (5.9%)}",
        ])
    }

    func testParseMessageFromStringMultiLineDollarFormula() {
        let input = """
        Bayes' theorem:
        $$
        P(A|B) = \\frac{P(B|A) \\times P(A)}{P(B)}
        $$
        Done.
        """

        let result = parser.parseMessageFromString(input: input).map(describe)
        XCTAssertEqual(result, [
            "text: Bayes' theorem:",
            "formula: P(A|B) = \\frac{P(B|A) \\times P(A)}{P(B)}",
            "text: Done.",
        ])
    }

    /*
     Lines that contain $$ but are not standalone display math stay text
     */
    func testParseMessageFromStringDollarSignsInText() {
        let input = """
        4. **Multiply by contribution:** $$500 \\times 520.92666 = \\mathbf{$260,463.33}$
        $$x$$ where $x$ is the unknown
        $$$$
        """

        let result = parser.parseMessageFromString(input: input).map(describe)
        XCTAssertEqual(result, ["text: " + input])
    }

    /*
     $$ inside code and thinking blocks is content, not display math
     */
    func testParseMessageFromStringDollarSignsInCodeAndThinking() {
        let input = """
        ```latex
        $$
        E=mc^2
        $$
        ```
        <think>
        $$x$$
        </think>
        $$y$$
        """

        let result = parser.parseMessageFromString(input: input).map(describe)
        XCTAssertEqual(result, [
            "code(latex): $$\nE=mc^2\n$$",
            "thinking: $$x$$",
            "formula: y",
        ])
    }

    /*
     Inline math delimiters, with cases from Gemini output; dollar amounts and inline code stay text
     */
    func testInlineMathFormulas() {
        func latex(_ text: String) -> [String] {
            InlineMath.formulas(in: text).map { $0.latex }
        }

        XCTAssertEqual(latex("solve for $x$ by completing the square. (Assume $a \\neq 0$)."), ["x", "a \\neq 0"])
        XCTAssertEqual(latex("- \\( S \\) is the action."), [" S "])
        XCTAssertEqual(latex("Choose $x_i^*$ in each $i$-th subinterval"), ["x_i^*", "i"])
        XCTAssertEqual(latex("$\\$500 \\times 520.92666 = \\mathbf{\\$260,463.33}$"), ["\\$500 \\times 520.92666 = \\mathbf{\\$260,463.33}"])
        XCTAssertEqual(latex("multiply by $(1 + r)$, which yields **$261,982.70**)."), ["(1 + r)"])
        XCTAssertEqual(latex("It costs between $5 and $10, or $5-$10."), [])
        XCTAssertEqual(latex("Run `echo $HOME/$PATH` first"), [])
        XCTAssertEqual(latex("Display math $$x$$ mid-line is not inline"), [])
    }

    private func describe(_ element: MessageElements) -> String {
        switch element {
        case .text(let text): return "text: \(text)"
        case .formula(let formula): return "formula: \(formula)"
        case .code(let code, let lang, _): return "code(\(lang)): \(code)"
        case .thinking(let thinking, _): return "thinking: \(thinking)"
        default: return "\(element)"
        }
    }
}
