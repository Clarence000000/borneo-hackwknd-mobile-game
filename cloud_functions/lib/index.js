"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.processInsurancePayout = exports.evaluateLoan = exports.calculateBnplPenalty = exports.weatherCheck = exports.calculateCreditScore = void 0;
var creditScore_1 = require("./creditScore");
Object.defineProperty(exports, "calculateCreditScore", { enumerable: true, get: function () { return creditScore_1.calculateCreditScore; } });
var weatherCheck_1 = require("./weatherCheck");
Object.defineProperty(exports, "weatherCheck", { enumerable: true, get: function () { return weatherCheck_1.weatherCheck; } });
var bnplCalculation_1 = require("./bnplCalculation");
Object.defineProperty(exports, "calculateBnplPenalty", { enumerable: true, get: function () { return bnplCalculation_1.calculateBnplPenalty; } });
var loanEvaluation_1 = require("./loanEvaluation");
Object.defineProperty(exports, "evaluateLoan", { enumerable: true, get: function () { return loanEvaluation_1.evaluateLoan; } });
var insurancePayout_1 = require("./insurancePayout");
Object.defineProperty(exports, "processInsurancePayout", { enumerable: true, get: function () { return insurancePayout_1.processInsurancePayout; } });
//# sourceMappingURL=index.js.map