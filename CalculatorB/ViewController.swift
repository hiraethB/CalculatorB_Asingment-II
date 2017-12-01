//
//  ViewController.swift
//  CalculatorB
//
//  Created by Boris V on 20.10.2017.
//  Copyright © 2017 GRIAL. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var display: UILabel!
    @IBOutlet weak var sequence: UILabel!
    @IBOutlet weak var displayM: UILabel!
    
    
    
    private let decimalSeparator = numberFormatter.decimalSeparator! // Региональный десятичный разделитель
    @IBOutlet weak var point: UIButton! {
        didSet {
            point.setTitle( decimalSeparator, for: .normal)
        }
    }
    // Переключение с радиан на градусы и обратно
    @IBOutlet weak var radDeg: UILabel!
    @IBOutlet weak var degreese: UIButton!
    @IBAction func degRad(_ sender: UIButton) {
        if sender.currentTitle != "Deg" {
            sender.setTitle("Deg", for: .normal)
            radDeg.text = "  rad"
        } else {
            sender.setTitle("rad", for: .normal)
            radDeg.text = ""
        }
    }
    
    private var brain = CalculatorBrain()
    private var userInTheMiddleOfTyping = false // флаг начатого и незаконченного цифрового ввода
    @IBAction func touchDigit(_ sender: UIButton) {
        let digit = sender.currentTitle!
        if !userInTheMiddleOfTyping { // это первый вводимый символ с цифровой клавиатуры
            display.text = digit != decimalSeparator ? digit :  "0" + digit
            userInTheMiddleOfTyping = true
        } else {
            let textCurrentlyInDisplay = display.text!
            if !textCurrentlyInDisplay.contains( decimalSeparator) || digit != decimalSeparator {
                display.text = textCurrentlyInDisplay + digit
            }
        }
        if !displayResult.isPending { // пример 5+6=7 будет показано “… “ ( 7 на display)
            sequence.text = "..."
        }
    }
    
    @IBOutlet weak var sin: UIButton!
    @IBOutlet weak var cos: UIButton!
    @IBOutlet weak var tan: UIButton!
    
    private var inverse = false
 
    @IBAction func inverseFunction() {
    inverse = !inverse
        if inverse {
            brain.performOperation("Inverse")
            tan.setTitle( "atan", for: .normal)
            sin.setTitle( "asin", for: .normal)
            cos.setTitle( "acos", for: .normal)
        } else {
            brain.performOperation("Direct")
            tan.setTitle( "tan", for: .normal)
            sin.setTitle( "sin", for: .normal)
            cos.setTitle( "cos", for: .normal)
        }
    }
    
    // разрешение предположения профессора (всегда ли строку цифрового ввода можно интерпретировать как Double)
    private var displayValue : Double? {
        get  {
            if  display.text != nil {
                return numberFormatter.number( from: display.text!) as? Double
            }
            return nil
        } set {
            if let new = newValue {
                display.text = numberFormatter.string(from: NSNumber( value: new))
            }
        }
    }
    
    private func displResult() {
        displayResult = brain.evaluate(using: variableCollection)
    }
    
    private var displayResult: ( result: Double?, isPending: Bool, description: String, error: String?) = ( nil, false, "", nil) {
        didSet {
            switch displayResult {
            case (nil, _, "", nil) : displayValue = 0 // ""
            case (let result, _,_, nil):
                displayValue = result
                displayM.text = numberFormatter.string(from: NSNumber(value: variableCollection["Ⓜ️"] ?? 0))
            case (_, _,_,let error): display.text = error!
            }
            sequence.text = displayResult.description + (displayResult.isPending ? " …" : " =")
        }
    }
    
    @IBAction func performOperation(_ sender: UIButton) { // выполнить операцию
        if userInTheMiddleOfTyping { // Если в середине ввода числа, то при вводе операции
            userInTheMiddleOfTyping = false // зафиксировать окончание ввода операнда
            if displayValue != nil {
                brain.setOperand( displayValue!) //  установить операнд и описание операции
            }
        }
        // передать для вычисления символ операции    
        brain.performOperation(sender.currentTitle!)
        displResult() // результат вычислений
    }

    @IBAction func backSpaceOrUndo() {
        if userInTheMiddleOfTyping {
            if !display.text!.isEmpty { // количество символов строки дисплея
                display.text!.removeLast()
                if display.text!.isEmpty {
                    userInTheMiddleOfTyping = false
                    displResult()
                }
            } else {
                userInTheMiddleOfTyping = false
                displResult()
            }
        } else {
            brain.undo()
            displResult()
        }
    }
    
    @IBAction func reset() {
        userInTheMiddleOfTyping = false
        brain.reset()
        displResult()
        sequence.text = String() // пустая строка ленты (, что и при включении симулятора)
        variableCollection ["Ⓜ️"] = nil
        radDeg.text = "  rad"
        degreese.setTitle("Deg", for: .normal)
    }
    //=============================================================
    private var variableCollection = [String: Double] ()
    
    @IBAction func setVariable(_ sender: UIButton) { // кнопка < ➙M >
        if variableCollection.isEmpty {
            variableCollection["Ⓜ️"] = displayValue
        } else {
            variableCollection["Ⓜ️"] = nil
        }
        displResult()
        userInTheMiddleOfTyping = false // зафиксировать окончание ввода операнда ( <M> - тоже операнд)
    }
    // вычисление с "переменной"
    @IBAction func evaluteVariable(_ sender: UIButton) { // кнопка < М >
        brain.setOperand(variable: "Ⓜ️")
        displResult()
    }
}

