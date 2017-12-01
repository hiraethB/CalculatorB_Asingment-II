//
//  CalculatorBrain.swift
//  CalculatorB
//
//  Created by Boris V on 20.10.2017.
//  Copyright © 2017 GRIAL. All rights reserved.
//

import Foundation
// Форматтер
let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter () // создаем методы
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 6
    formatter.locale = NSLocale.current
    return formatter
} ()

struct CalculatorBrain {
    
    private enum Operation {
        case constant(Double)
        case equals
        case randOperation(() -> Double,String)
        case unaryOperation (( Double) -> Double, ((String) -> String)?, (( Double) -> String?)?)
        case binaryOperation ((Double, Double) -> Double, ((String, String) -> String)?, (( Double, Double) -> String?)?, Int)
        case rad (Double)
        case deg (Double)
        case invFunctions (Bool)
        case dirFunctions (Bool)
    }
    
    private var operations : Dictionary< String, Operation> = [ // более понятная сокращенная запись словаря просто = [String: Operation]
        "π" : Operation.constant(Double.pi),
        "e" : Operation.constant(M_E),
        "√" : Operation.unaryOperation(sqrt, { "√(" + $0 + ")" }, { $0 < 0 ? " √negative number" : nil}),
        "∛" : Operation.unaryOperation({pow($0, 1/3)}, { "∛(" + $0 + ")" }, nil),
        "±" : Operation.unaryOperation({ -$0 }, { "±(" + $0 + ")" }, nil),
        "x²" : Operation.unaryOperation({ $0*$0 }, { "(" + $0 + ")²" }, nil),
        "x³" : Operation.unaryOperation({pow($0, 3)}, { "(" + $0 + ")³" }, nil),
        "×" : Operation.binaryOperation( *, nil, nil, 1),
        "÷" : Operation.binaryOperation( /, nil, { $1 == 0 ? " division by zero" : nil}, 1),
        "+" : Operation.binaryOperation( +, nil, nil, 0),
        "-" : Operation.binaryOperation( -, nil, nil, 0),
        "=" : Operation.equals,
        "Rand" : Operation.randOperation({ Double(arc4random_uniform(UInt32.max)) / Double(UInt32.max)},"Rand"),
        "sin" : Operation.unaryOperation(sin, nil, nil),
        "cos" : Operation.unaryOperation(cos, nil, nil),
        "tan": Operation.unaryOperation(tan, nil, nil),
        "asin" : Operation.unaryOperation( asin, nil,{ abs($0) > 1.0 ? "вне диапазона, >|1|" : nil }),
        "acos" : Operation.unaryOperation( acos, nil, { abs($0) > 1.0 ? "вне диапазона, >|1|" : nil }),
        "atan" : Operation.unaryOperation( atan, nil, nil),
        "Inverse": Operation.invFunctions(true),
        "Direct": Operation.dirFunctions(false),
        "rad" : Operation.deg( Double.pi/180 ),
        "Deg" : Operation.rad (1.0)
    ]
    
    private struct PendingBinaryOperation { // структура для запоминания свойств отложенной бинарной операции
        let function: (Double, Double) -> Double
        let firstOperand: Double
        var descriptionFunction: (String, String) -> String // описание отложенной бинарной операции
        var descriptionOperand: String // описание первого операнда
        var validator: ((Double, Double) -> String?)?
        var prevPrecedence: Int // приоритет предыдущей операции
        var precedence: Int // приоритет бинарной операции
        
        func perform(with secondOperand: Double) -> Double {
            return function( firstOperand, secondOperand)
        }
        // Построение описания с учётом приоритетов бинарных операций
        func buildDescription (with secondOperand: String) -> String {
            var new = descriptionOperand //  текущее описание операнда
            if  precedence > prevPrecedence { // приоритет последней операции выше?
                new = "(" + new + ")"  // изменить описание операнда
            }
            return descriptionFunction ( new, secondOperand)
        }
        
        func validate (with secondOperand: Double) -> String? {
            guard let validator = validator  else {return nil}
            return validator (firstOperand, secondOperand)
        }
    }
    //------------------------------------------------
    private var countingSticks = [Treasure] ()
    private enum Treasure {
        case operand ( Double), operation( String) , variable( String)
    }
    //=================================================================
    func evaluate(using variables: Dictionary<String,Double>? = nil)
        -> (result: Double?, isPending: Bool, description: String, error: String?) {
            
            var accumulator: ( value: Double?, description: String?, kTrigonometry: Double, inverseFunction: Bool) = (0,"", 1, false)
            var prevPrecedence = Int.max // первичная установка приоритета предыдущей операции
            var error: String?
            
            func setOperand (_ operand: Double) {
                accumulator.value = operand
                if let next = accumulator.value {
                    accumulator.description = numberFormatter.string(from: NSNumber(value: next)) ?? ""
                }
            }
            
            var result: Double? {
                return accumulator.value
            }
            
            func setOperand(variable named: String) {
                accumulator.value = variables?[named] ?? 0
                accumulator.description =  named
            }
            
            var pendingBinaryOperation: PendingBinaryOperation? // отложенная бинарная операция
            
            var resultIsPending: Bool {
                return pendingBinaryOperation != nil
            }
            
            func performOperation (_ symbol: String) {
                if let operation = operations[symbol] {
                    switch operation {
                        
                    case .invFunctions (let value) :
                        accumulator.inverseFunction = value
                    case .dirFunctions (let value) :
                        accumulator.inverseFunction = value
                    case .rad (let value) :
                        accumulator.kTrigonometry = value
                    case .deg (let value) :
                        accumulator.kTrigonometry = value
                        
                    case .unaryOperation (let function, var descriptionFunction, let validator):
                        guard accumulator.value != nil else { return}
                            error = validator?( accumulator.value!)
                        if  descriptionFunction != nil {
                            accumulator.value = function( accumulator.value!)
                        } else {
                            if accumulator.inverseFunction { // обратные функции
                                accumulator.value = function( accumulator.value!) * 1/accumulator.kTrigonometry
                            } else {
                                accumulator.value = function( accumulator.value! * accumulator.kTrigonometry)
                            }
                            if accumulator.kTrigonometry != 1 { //градусы
                                descriptionFunction = {symbol + "d(" + $0 + ")"}
                            } else { // радианы
                                descriptionFunction = {symbol + "(" + $0 + ")"}
                            }
                        }
                        // запись строки описания операндов и функций после выполнения операции
                        accumulator.description = descriptionFunction!( accumulator.description!)
                        
                    case .binaryOperation( let function, var descriptionFunction, let validator, let precedence):
                        performPendingBinaryOperation()
                        // отложенная бинарная операция
                        if accumulator.value != nil {
                            if  descriptionFunction == nil {
                                descriptionFunction = {$0 + symbol + $1}
                            }
                            // Запомнить первый операнд, операцию, их описания, описание их последовательности и приоритет операции
                            pendingBinaryOperation = PendingBinaryOperation (function:function,
                                                                             firstOperand:accumulator.value!,
                                                                             descriptionFunction: descriptionFunction!,
                                                                             descriptionOperand: accumulator.description!,
                                                                             validator: validator,
                                                                             prevPrecedence: prevPrecedence,
                                                                             precedence: precedence)
                            // операция выполнена
                            accumulator.value = nil
                            accumulator.description = nil
                        }
                    case .constant(let value):
//                        if value == .pi && accumulator.kTrigonometry == .pi/180 {
//                          accumulator.value = 180
//                        } else {
                        accumulator.value = value
//                       }
                        accumulator.description = symbol
                    case .equals:
                        performPendingBinaryOperation() // к выполнению бинарной операции
                        
                    case .randOperation (let function, let descriptionValue):
                        accumulator.value = function()
                        accumulator.description = descriptionValue
                    }
                }
            }
            
            func  performPendingBinaryOperation() {
                if pendingBinaryOperation != nil && accumulator.value != nil {
                    
                    error = pendingBinaryOperation!.validate(with: accumulator.value!)
                    
                    accumulator.value =  pendingBinaryOperation!.perform(with: accumulator.value!)
                    // вызов функции контроля приоритетов бинарных операций и запись строки описания операндов и функций после выполнения бинарной операции
                    accumulator.description = pendingBinaryOperation!.buildDescription(with: accumulator.description!)
                    // запись приоритета последней бинарной операции для сравнения с приоритетом будущей
                    prevPrecedence = pendingBinaryOperation!.precedence
                    
                    pendingBinaryOperation = nil // отложенная бинарная операция выполнена, сбросить флаг
                }
            }
            //Последовательность операндов и операций над ними
            var description: String? {
                if pendingBinaryOperation == nil {
                    return accumulator.description
                } else {
                    return pendingBinaryOperation!.descriptionFunction( pendingBinaryOperation!.descriptionOperand, accumulator.description ?? "")
                }
            }
            // +++++++++++++++++++++++++++++++++++++ тело func evaluate
            guard !countingSticks.isEmpty else { return( nil, false, "", nil)}
            for i in countingSticks {
                switch i {
                case .operand(let operand):
                    setOperand(operand)
                case .operation(let operation):
                    performOperation(operation)
                case .variable(let symbol):
                    setOperand (variable:symbol)
                }
            }
            return (result, resultIsPending, description ?? "", error)
    }
    // блок внешних свойств ===============================
    mutating func undo() {
        if !countingSticks.isEmpty {
            countingSticks.removeLast()
        }
    }
    // Входное значение операнда "число"
    mutating func setOperand(_ operand: Double) {
        countingSticks.append(Treasure.operand(operand))
    }
    // Вход для символьной строки операции
    mutating func performOperation(_ symbol : String) {
        //  countingSticks.operation[symbol]
        countingSticks.append(Treasure.operation( symbol))
    }
    // Вход для символьной строки операнда "переменная"
    mutating func setOperand( variable named: String) {
        // countingSticks.variable[named]
        countingSticks.append(Treasure.variable( named))
    }
    // Входная функция сброса (С,-clear)
    mutating func reset() {
        countingSticks.removeAll()
        
    }
    //========deprecated=======================================================
    // Выход, значение результата вычисления
    @available(iOS, deprecated, message: "Used evaluate instead")
    var result: Double? {
        return evaluate().result
    }
    //Выходная последовательность операндов и операций над ними
    @available(iOS, deprecated, message: "Used evaluate instead")
    var description: String? {
        return evaluate().description
    }
    // Вспомогательная переменная для формирования последовательности - флаг отложенной операции
    @available(iOS, deprecated, message: "Used evaluate instead")
    var resultIsPending: Bool {
        return evaluate().isPending
    }
}


