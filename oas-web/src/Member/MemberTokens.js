import { gql, useQuery } from "@apollo/client";
import { useParams, useOutletContext } from "react-router-dom";

import { get } from 'lodash'
import { Tokens } from "../Money/Tokens";
import { useEffect } from "react";


export const MemberTokens = (params) => {
  const { setTitle } = useOutletContext();

  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const { data } = useQuery(gql`
    query ($member_id: Int!) {
      member(member_id: $member_id) {
        id,
        name,
        token_count
      }
    }
  `, {
    variables: {
      member_id: parseInt(id)
    }
  })

  useEffect(() => {
    setTitle(`Member: ${get(data, 'member.name', id)}'s Tokens: ${get(data, 'member.token_count', 0)}`);
  }, [data])

  return <div>
    <Tokens member_id={id} />
  </div>
}
