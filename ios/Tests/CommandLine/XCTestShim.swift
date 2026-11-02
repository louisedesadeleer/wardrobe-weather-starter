// Apple Command Line Tools omit XCTest. Run the same assertions without its runner.
import Foundation
class XCTestCase {}
var failures = 0
func report(_ message: String, file: StaticString, line: UInt) { failures += 1; print("FAIL \(file):\(line) \(message)") }
func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) { if !value() { report("Expected true",file:file,line:line) } }
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) { if value() { report("Expected false",file:file,line:line) } }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () -> T, _ b: @autoclosure () -> T, file: StaticString = #filePath, line: UInt = #line) { let left = a(), right = b(); if left != right { report("\(left) != \(right)",file:file,line:line) } }
func XCTAssertNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #filePath, line: UInt = #line) { if value() != nil { report("Expected nil",file:file,line:line) } }
func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #filePath, line: UInt = #line) { if value() == nil { report("Expected a value",file:file,line:line) } }
func XCTAssertThrowsError<T>(_ value: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) { do { _ = try value(); report("Expected error",file:file,line:line) } catch {} }
func XCTAssertNoThrow<T>(_ value: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) { do { _ = try value() } catch { report("Unexpected error: \(error)",file:file,line:line) } }
