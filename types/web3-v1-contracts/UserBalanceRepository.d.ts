/* Generated by ts-generator ver. 0.0.8 */
/* tslint:disable */

import BN from "bn.js";
import { ContractOptions } from "web3-eth-contract";
import { EventLog } from "web3-core";
import { EventEmitter } from "events";
import {
  Callback,
  PayableTransactionObject,
  NonPayableTransactionObject,
  BlockType,
  ContractEventLog,
  BaseContract
} from "./types";

interface EventOptions {
  filter?: object;
  fromBlock?: BlockType;
  topics?: string[];
}

export interface UserBalanceRepository extends BaseContract {
  constructor(
    jsonInterface: any[],
    address?: string,
    options?: ContractOptions
  ): UserBalanceRepository;
  clone(): UserBalanceRepository;
  methods: {
    findReserveIndexOrCreate(
      _user: string,
      _reserve: string
    ): NonPayableTransactionObject<string>;

    increaseUserDeposit(
      _user: string,
      _reserve: string,
      _amount: number | string
    ): NonPayableTransactionObject<void>;

    decreaseUserDeposit(
      _user: string,
      _reserve: string,
      _amount: number | string
    ): NonPayableTransactionObject<void>;

    increaseUserBorrow(
      _user: string,
      _reserve: string,
      _amount: number | string
    ): NonPayableTransactionObject<void>;

    decreaseUserBorrow(
      _user: string,
      _reserve: string,
      _amount: number | string
    ): NonPayableTransactionObject<void>;

    getUserReservesQty(_user: string): NonPayableTransactionObject<string>;

    getUserReserveBalance(
      _user: string,
      _index: number | string
    ): NonPayableTransactionObject<{
      reserve: string;
      deposited: string;
      borrowed: string;
      0: string;
      1: string;
      2: string;
    }>;
  };
  events: {
    allEvents(options?: EventOptions, cb?: Callback<EventLog>): EventEmitter;
  };
}
