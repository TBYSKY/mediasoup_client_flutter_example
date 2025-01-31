/*
 * @Author: Beoyan
 * @Date: 2022-08-12 15:14:44
 * @LastEditTime: 2022-08-12 16:09:49
 * @LastEditors: Beoyan
 * @Description: r
 */
part of '../../../features/producers/bloc/producers_bloc.dart';

abstract class ProducersEvent extends Equatable {
  const ProducersEvent();
}

class ProducerAdd extends ProducersEvent {
  final Producer producer;

  const ProducerAdd({required this.producer});

  @override
  List<Object> get props => throw UnimplementedError();
}

class ProducerRemove extends ProducersEvent {
  final String source;

  const ProducerRemove({required this.source});

  @override
  List<Object> get props => [source];
}

class ProducerPaused extends ProducersEvent {
  final String source;

  const ProducerPaused({required this.source});

  @override
  List<Object> get props => [source];
}

class ProducerResumed extends ProducersEvent {
  final String source;

  const ProducerResumed({required this.source});

  @override
  List<Object> get props => [source];
}
