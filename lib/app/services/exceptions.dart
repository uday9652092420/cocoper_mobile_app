import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ServerException implements Exception {
  final ErrorModel errModel;

  ServerException({
    required this.errModel,
  });
}

class ErrorModel {
  final int status;
  final String errorMessage;

  ErrorModel({
    required this.status,
    required this.errorMessage,
  });

  factory ErrorModel.fromJson(Map<String, dynamic> jsonData) {
    return ErrorModel(
      status: jsonData[ExceptionMessages.status] is int
          ? jsonData[ExceptionMessages.status] as int
          : int.tryParse(
                jsonData[ExceptionMessages.status]?.toString() ?? '',
              ) ??
              0,
      errorMessage: jsonData[ExceptionMessages.errorMessage]?.toString() ?? '',
    );
  }
}

class ExceptionMessages {
  static const connectionTimeout = "Connection timeout";
  static const sendTimeout = "Send timeout";
  static const receiveTimeout = "Receive timeout";
  static const badCertificate = "Bad Certificate";
  static const requestCanceled = "Request Canceled";
  static const connectionError = "Connection Error";
  static const responseUnKnow = "Response UnKnow";
  static const statusCode400 = "Bad Response : StatusCode 400";
  static const statusCode401 = "Bad Response : StatusCode 401";
  static const statusCode403 = "Bad Response : StatusCode 403";
  static const statusCode404 = "Bad Response : StatusCode 404";
  static const statusCode409 = "Bad Response : StatusCode 409";
  static const statusCode422 = "Bad Response : StatusCode 422";
  static const statusCode504 = "Bad Response : StatusCode 504";

  static const String status = "status";
  static const String errorMessage = "ErrorMessage";
}

String handleDioExceptions(DioException e) {
  String errorMessage = e.message.toString();

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      errorMessage = ExceptionMessages.connectionTimeout;
      break;

    case DioExceptionType.sendTimeout:
      errorMessage = ExceptionMessages.sendTimeout;
      break;

    case DioExceptionType.receiveTimeout:
      errorMessage = ExceptionMessages.receiveTimeout;
      break;

    case DioExceptionType.badCertificate:
      errorMessage = ExceptionMessages.badCertificate;
      break;

    case DioExceptionType.cancel:
      errorMessage = ExceptionMessages.requestCanceled;
      break;

    case DioExceptionType.connectionError:
      errorMessage = ExceptionMessages.connectionError;
      break;

    case DioExceptionType.unknown:
      errorMessage = ExceptionMessages.responseUnKnow;
      break;

    case DioExceptionType.badResponse:
      switch (e.response?.statusCode) {
        case 400:
          errorMessage = ExceptionMessages.statusCode400;
          break;

        case 401:
          errorMessage = ExceptionMessages.statusCode401;
          break;

        case 403:
          errorMessage = ExceptionMessages.statusCode403;
          break;

        case 404:
          errorMessage = ExceptionMessages.statusCode404;
          break;

        case 409:
          errorMessage = ExceptionMessages.statusCode409;
          break;

        case 422:
          errorMessage = ExceptionMessages.statusCode422;
          break;

        case 504:
          errorMessage = ExceptionMessages.statusCode504;
          break;

        default:
          errorMessage = e.message?.toString() ?? 'Bad response from server';
          break;
      }
      break;
  }

  debugPrint(errorMessage);

  return errorMessage;
}

// String errorMessage = "";
// bool isFromAPI = false;

// void fnHandleControllerException(
//   error,
//   stackTrace,
//   module,
//   methodName,
// ) async {
//   if (error is DioException) {
//     isFromAPI = true;
//     errorMessage = handleDioExceptions(error).toString();
//
//     debugPrint(errorMessage);
//     debugPrint(stackTrace.toString());
//   } else {
//     isFromAPI = false;
//     errorMessage = error.toString();
//
//     debugPrint("Other Errors: ${error.toString()}");
//   }
//
//   Map<String, dynamic> requestBody = {
//     'AppName': "CRM flutter app",
//     'ModuleName': module,
//     'MethodName': methodName,
//     'Message': errorMessage,
//     "StackTrace": stackTrace.toString(),
//     "IsFromAPI": isFromAPI,
//   };
//
//   debugPrint(requestBody.toString());
//
//   var response = await AuthRepository.postLogException(requestBody);
//
//   debugPrint(response.data.toString());
// }
