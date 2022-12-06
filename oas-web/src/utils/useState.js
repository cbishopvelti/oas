import { useState as useReactState } from "react";


export const useState = (initState, {id}) => {

  const localState = JSON.parse(localStorage.getItem(id));
  const [reactState, setReactState] = useReactState(localState || initState);

  const localSetState = (newState) => {
    localStorage.setItem(id, JSON.stringify(newState, null, 2));
    setReactState(newState);
  }

  return [reactState, localSetState]
}