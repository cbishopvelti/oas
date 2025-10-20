import { useState, useEffect } from 'react'
import {
  Box,
  FormControl,
  Stack,
  TextField,
  Alert,
  InputLabel,
  FormControlLabel,
  Switch,
  Button,
  FormHelperText
} from "@mui/material"
import { get, setWith, clone, find, snakeCase, has, startsWith } from 'lodash'
import { useMutation, gql} from '@apollo/client'
import { useNavigate, generatePath, createSearchParams, useOutletContext } from 'react-router-dom'
import moment from 'moment';

const onChange = ({formData, setFormData, isCheckbox, key}) => (event) => {
  let value = event.target.value

  if (isCheckbox) {
    value = event.target.checked
  }

  formData = setWith(clone(formData), key, value, clone)
  setFormData(formData)
}

const parseErrors = (errors) => {

  return errors.reduce((acc, error) => {
    if (error.db_field) {
      return {
        ...acc,
        [error.db_field]: [error.message, ...get(acc, error.db_field, [])],
      }
    }

    // let result = error.message.match(/In\s(argument|field)\s"/g)
    let result;
    const regex = /(In\s(argument|field)|Variable)\s"(.+?)":\s([^\.]+.)/g;
    let found = false;
    while(result = regex.exec(error.message)) {
      const key = snakeCase(result[3]);
      acc = {
        ...acc,
        [key]: [result[4], ...get(acc, key, [])]
      }
      found = true
    }
    if ( found == false) {
      acc = {
        ...acc,
        global: [error.message, ...get(acc, "global", [])]
      }
    }

    return acc;
  }, {})
}

export const MembershipForm = () => {
  const defaultFormData = {member_details: {}};
  const [formData, setFormData] = useState(defaultFormData);
  const [outletContext] = useOutletContext();
  const navigate = useNavigate();
  const [disableLocalStorageUntil, setDisableLocalStorageUntil] = useState(
    localStorage.getItem("disable_registration_until") ? moment(localStorage.getItem("disable_registration_until")) : false
  )

  const [mutation, { error }] = useMutation(gql`
    mutation ($name: String!, $email: String!, $password: String, $member_details: MemberDetailsArg!) {
      public_register (name: $name, email: $email, member_details: $member_details, password: $password) {
        success
      }
    }
  `)

  let gqlErrors = get(error, 'graphQLErrors', [])
  // const disable_registration = get(errors, "")
  const errors = parseErrors(gqlErrors);

  useEffect(() => {
    const exists = find(errors.name, (erro) => startsWith(erro, "name: Name already exists"))
    if (exists) {
      const disable_until = moment().add(1, "hours")
      setDisableLocalStorageUntil(disable_until)
      localStorage.setItem("disable_registration_until", disable_until.toISOString())
    }
  }, [gqlErrors])

  const register = (formData) => async () => {
    const result = await mutation({
      variables: formData
    })

    const path = generatePath("/register/success?:queryString", {
      queryString: createSearchParams({
        email: formData.email
      }).toString()
    });

    outletContext.refetchUser();

    if (result?.data?.public_register?.success) {
      navigate(path);
    }
  }
  // console.log("001", disableLocalStorageUntil.toString(), moment().toString(), disableLocalStorageUntil.isAfter(moment()))
  return <Stack spacing={2}>
    <Stack sx={{ width: '100%' }}>
        {get(errors, "global", []).map((message, i) => (
            <Alert key={i} sx={{m:2}} severity="error">{message}</Alert>
        ))}
      </Stack>
    <p>
      Please complete this form to become a either a member/temporary member. In order to become a full member after you initial 3 jams/events, please pay the membership fee.
    </p>

    <FormControl fullWidth>
      <TextField
        required
        id="name"
        label="Name"
        value={get(formData, "name", '')}
        onChange={onChange({formData, setFormData, key: "name"})}
        error={has(errors, "name")}
        helperText={get(errors, "name", []).join(" ")}
      />
    </FormControl>

    <FormControl fullWidth>
      <TextField
        required
        id="email"
        label="Email"
        value={get(formData, "email", '')}
        onChange={onChange({formData, setFormData, key: "email"})}
        error={has(errors, "email")}
        helperText={get(errors, "email", []).join(" ")}
      />
    </FormControl>

    {outletContext.enableBooking && <FormControl fullWidth>
      <TextField
        required
        id="password"
        label="Password"
        value={get(formData, "password", '')}
        onChange={onChange({formData, setFormData, key: "password"})}
        error={has(errors, "password")}
        helperText={get(errors, "password", []).join(" ")}
        type='password'
      />
    </FormControl>}

    <FormControl>
      <TextField
        id="phone"
        required
        label={'Phone Number'}
        value={get(formData, 'member_details.phone', '')}
        onChange={onChange({formData, setFormData, key: "member_details.phone"})}
        error={has(errors, "phone")}
        helperText={get(errors, "phone", []).join(" ")}
      />
    </FormControl>
    <FormControl>
      <TextField
        id="address"
        required
        label={'Address'}
        value={get(formData, 'member_details.address', '')}
        onChange={onChange({formData, setFormData, key: "member_details.address"})}
        multiline={true}
        minRows={2}
        error={has(errors, "address")}
        helperText={get(errors, "address", []).join(" ")}
      />
    </FormControl>
    <FormControl>
      <TextField
        required
        id="dob"
        label="Date of Birth"
        value={get(formData, "member_details.dob", '')}
        type="date"
        onChange={
          onChange({formData, setFormData, key: "member_details.dob"})
        }
        InputLabelProps={{
          shrink: true,
        }}
        error={has(errors, "dob")}
        helperText={get(errors, "dob", []).join(" ")}
        />
    </FormControl>

    <h3>Next of Kin</h3>
    <FormControl fullWidth>
      <TextField
        required
        id="nok_name"
        label="Next of Kin Name"
        value={get(formData, "member_details.nok_name", '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_name"})}
        error={has(errors, "nok_name")}
        helperText={get(errors, "nok_name", []).join(" ")}
      />
    </FormControl>

    <FormControl fullWidth>
      <TextField
        required
        id="nok_email"
        label="Next of Kin Email"
        value={get(formData, "member_details.nok_email", '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_email"})}
        error={has(errors, "nok_email")}
        helperText={get(errors, "nok_email", []).join(" ")}
      />
    </FormControl>
    <FormControl>
      <TextField
        id="nok_phone"
        required
        label={'Next of Kin Phone Number'}
        value={get(formData, 'member_details.nok_phone', '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_phone"})}
        error={has(errors, "nok_phone")}
        helperText={get(errors, "nok_phone", []).join(" ")}
      />
    </FormControl>
    <FormControl>
      <TextField
        id="nok_address"
        required
        label={'Next of Kin Address'}
        value={get(formData, 'member_details.nok_address', '')}
        onChange={onChange({formData, setFormData, key: "member_details.nok_address"})}
        multiline={true}
        minRows={2}
        error={has(errors, "nok_address")}
        helperText={get(errors, "nok_address", []).join(" ")}
      />
    </FormControl>

    <div>

      <h3>Agreement of Release and Waiver of Liability</h3>
      <p>
        The constitution: <a href="https://drive.google.com/file/d/1g2blgY6CL9IMuXT-8EJzvLMQTaiIGt2p/view">https://drive.google.com/file/d/1g2blgY6CL9IMuXT-8EJzvLMQTaiIGt2p/view?usp=sharing</a><br />
        <br/>
        By agreeing to the membership form<br/>
        - you recognize that insurance is in the responsibility of the participant and that you have an adequate accident insurance.<br/>
        - you agree that acrobatics require physical exertion that may be strenuous and may cause physical injury, and that you're fully aware of the risks and hazards involved.<br/>
        - you verify, and warrant that you're physically fit and that you have no medical condition that would prevent your full participation in this workshop.<br/>
        - you knowingly, voluntarily and expressly waive any claim you may have against by the organisers, for injury or damages that you may sustain as a result of participating in jams organised by the society.<br/>
      </p>
    </div>
    <FormControl>

        <FormControlLabel
          control={
            <Switch
              value={get(formData, 'member_details.agreed_to_tac')}
              onChange={onChange({formData, setFormData, key: "member_details.agreed_to_tac", isCheckbox: true})}
            />
          }
          label="I agree to the above"
          />
      <FormHelperText
        error={has(errors, 'agreed_to_tac')}>
        {get(errors, 'agreed_to_tac', []).join(' ')}
      </FormHelperText>
    </FormControl>

    <FormControl >
      <Button
        disabled={disableLocalStorageUntil && disableLocalStorageUntil.isAfter(moment())}
        onClick={register(formData)}>Register</Button>
      <FormHelperText
        error={disableLocalStorageUntil && disableLocalStorageUntil.isAfter(moment())}>
        This form has been disable due to previous invalid input. Contact support.
      </FormHelperText>
    </FormControl>

  </Stack>
}
