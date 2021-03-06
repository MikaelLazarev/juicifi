import React from "react";
import {Reserve} from "../../core/reserve";
import {DepositItem} from "./DepositItem";
import {Col, Container, Row} from "react-bootstrap";
import {LoadingView} from "rn-web-components";

export interface ReservesListWidgetProps {
  data: Array<Reserve>;
}

export function DepositListWidget({data}: ReservesListWidgetProps) {
  const reservesRendered =
    data.length === 0 ? (
      <LoadingView />
    ) : (
      data.map((reserve, i) => (
        <DepositItem
          data={reserve}
          backgroundColor={i % 2 === 0 ? "#e3e3e3" : "white"}
        />
      ))
    );
  return (
    <Container style={{textAlign: "center", marginTop: "3.5rem"}}>
      <Row style={{marginBottom: "1.5rem"}}>
        <h2 style={{margin: "auto", color: "#333"}}>Deposits</h2>
      </Row>
      <Row style={{minHeight: "40px", fontWeight: "bold"}}>
        <Col style={{textAlign: "left"}}>Assets</Col>
        <Col>Market size</Col>
        <Col>Deposit APY</Col>
        <Col>Deposit +V</Col>
        <Col>Queue</Col>
        <Col></Col>
      </Row>
      {reservesRendered}
    </Container>
  );
}
