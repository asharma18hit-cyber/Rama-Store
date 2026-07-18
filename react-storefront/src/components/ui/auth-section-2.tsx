"use client";

import { useEffect, useState, type ReactNode } from "react";
import { ArrowRight } from "lucide-react";

const images = [
  "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80",
  "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80",
  "https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=800&q=80",
  "https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?auto=format&fit=crop&w=800&q=80",
];

const prompts = [
  "private in a bot channel, 8k in the style of a painting, realism, Romantic style, a beautiful Swedish summer with a field of daisies a young blond Nordic woman in a white Romantic dress she is blocking the flowers, sunny summer day, intense beautiful colors",
  "Ultra realistic luxury eyewear campaign portrait, elegant woman wearing premium tortoiseshell glasses, warm mocha brown background, bright soft studio lighting, glowing skin, subtle gold earrings, rich warm color palette, sophisticated fashion photography, clean composition with negative space, magazine cover aesthetic, premium and inviting, hyper realistic",
  "Blurry chaotic timelapse of a faceless crowd moving rapidly through a dark brutalist concrete tunnel, flickering neon lights, motion blur, sensory overload, Fincher neo-noir style, hyper-kinetic, raw aesthetic",
  "Retro 1980s dark fantasy cartoon illustration, cult t-shirt graphic style. Close-up shot of a white duck smoking, the mascot for Camel cigarettes. He is depicted as a cartoon duck with human-like attributes, wearing dark, thick-rimmed sunglasses that reflect a subtle image of palm trees.",
];

const formFields = [
  { label: "First Name", value: "Harshit", type: "text" },
  { label: "Last Name", value: "Sharma", type: "text" },
];

const termsText = (
  <>
    By creating an account, you agree to our{" "}
    <a
      href="#"
      className="font-medium text-black/45 underline underline-offset-2 dark:text-white/45"
    >
      Terms and Services
    </a>{" "}
    and{" "}
    <a
      href="#"
      className="font-medium text-black/45 underline underline-offset-2 dark:text-white/45"
    >
      Privacy Policy
    </a>
  </>
);

export default function AuthSectionTwo() {
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    const interval = window.setInterval(() => {
      setActiveIndex((current) => (current + 1) % images.length);
    }, 2600);

    return () => window.clearInterval(interval);
  }, []);

  return (
    <section className="min-h-screen bg-white p-3 text-black antialiased [font-synthesis:none] dark:bg-[#050505] dark:text-white">
      <div className="grid min-h-[calc(100vh-1.5rem)] gap-6 lg:grid-cols-[0.94fr_1.06fr]">
        <div className="flex min-h-[760px] justify-center overflow-hidden rounded-md bg-black px-7 py-12 text-white sm:px-10 lg:min-h-0 lg:py-20 xl:py-24">
          <div className="flex w-full max-w-[500px] flex-col items-center">
            <div className="flex items-center gap-3 text-lg text-white">
              <MidjourneyLogo className="size-6" />
              Midjourney
            </div>

            <div className="relative mt-8 grid w-full grid-cols-[1.55fr_1fr] gap-2 rounded-md">
              <div className="pointer-events-none absolute inset-x-0 top-0 z-20 h-20 bg-gradient-to-b from-black to-transparent" />
              <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-24 bg-gradient-to-t from-black to-transparent" />
              <ImageTile
                src={images[0]}
                active={activeIndex === 0}
                className="row-span-2 h-[250px]"
              />
              <ImageTile
                src={images[1]}
                active={activeIndex === 1}
                className="h-[121px]"
              />
              <ImageTile
                src={images[3]}
                active={activeIndex === 3}
                className="h-[121px]"
              />
              <ImageTile
                src={images[2]}
                active={activeIndex === 2}
                className="col-span-2 h-[120px]"
              />
            </div>

            <div className="mt-6 w-full rounded-[10px] border border-dashed border-white/15 px-5 py-4">
              <div className="flex items-end gap-4">
                <p className="line-clamp-4 flex-1 text-xs leading-4 text-white/45">
                  <span className="font-semibold text-white">/imagine</span>{" "}
                  {prompts[activeIndex]}
                </p>
                <button className="grid size-8 shrink-0 place-items-center rounded-full bg-white/20 text-white transition-colors hover:bg-white/30">
                  <ArrowRight className="size-4" />
                </button>
              </div>
            </div>

            <p className="mt-7 max-w-[280px] text-center text-xl leading-tight text-white">
              A creative workspace for visionaries and builders
            </p>

            <div className="mt-auto flex gap-2 pb-8 pt-8">
              {prompts.map((_, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => setActiveIndex(index)}
                  className={
                    activeIndex === index
                      ? "h-1 w-10 rounded-full bg-white"
                      : "h-1 w-4 rounded-full bg-white/35"
                  }
                  aria-label={`Show prompt ${index + 1}`}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="flex min-h-[760px] items-center justify-center px-6 py-12 sm:px-10 lg:min-h-0 lg:px-14 xl:px-20">
          <AuthForm />
        </div>
      </div>
    </section>
  );
}

function ImageTile({
  src,
  active,
  className,
}: {
  src: string;
  active: boolean;
  className: string;
}) {
  return (
    <div
      className={`${className} relative overflow-visible rounded-md ${active ? "z-10" : "z-0"}`}
    >
      <img
        src={src}
        alt="Generated Midjourney artwork"
        className={`h-full w-full rounded-md object-cover transition-opacity duration-700 ${active ? "opacity-100" : "opacity-40"}`}
      />
      <FocusCorners active={active} />
    </div>
  );
}

function FocusCorners({ active }: { active: boolean }) {
  const baseClass = `pointer-events-none absolute h-4 w-4 border-white/60 transition-all duration-500 ease-out ${active ? "translate-x-0 translate-y-0 opacity-100" : "opacity-0"}`;

  return (
    <>
      <div
        className={`${baseClass} -left-2 -top-2 border-l border-t ${active ? "" : "-translate-x-2 -translate-y-2"}`}
      />
      <div
        className={`${baseClass} -right-2 -top-2 border-r border-t ${active ? "" : "translate-x-2 -translate-y-2"}`}
      />
      <div
        className={`${baseClass} -bottom-2 -left-2 border-b border-l ${active ? "" : "-translate-x-2 translate-y-2"}`}
      />
      <div
        className={`${baseClass} -bottom-2 -right-2 border-b border-r ${active ? "" : "translate-x-2 translate-y-2"}`}
      />
    </>
  );
}

function AuthForm() {
  return (
    <div className="mx-auto w-full max-w-[500px] text-center">
      <h1 className="whitespace-nowrap text-3xl font-medium tracking-[-0.04em] sm:text-4xl lg:text-[42px] lg:leading-[1.05]">
        Create an account
      </h1>

      <div className="mt-7 grid gap-3 sm:grid-cols-2">
        <SocialButton icon={<GoogleIcon />} label="Sign up with Google" />
        <SocialButton icon={<AppleIcon />} label="Sign up with Apple" />
      </div>

      <div className="my-8 flex items-center gap-4 text-sm text-black/60 dark:text-white/50">
        <div className="h-px flex-1 bg-black/15 dark:bg-white/15" />
        or
        <div className="h-px flex-1 bg-black/15 dark:bg-white/15" />
      </div>

      <form className="space-y-5 text-left">
        <div className="grid gap-5 sm:grid-cols-2">
          {formFields.map((field) => (
            <FieldBox
              key={field.label}
              label={field.label}
              value={field.value}
              type={field.type}
            />
          ))}
        </div>

        <FieldBox label="Email" value="harshitlog@gmail.com" type="email" />
        <FieldBox label="Password" value="*************" type="password" />

        <div className="space-y-3 pt-2 text-xs leading-4 text-black/30 dark:text-white/35 sm:text-[13px]">
          <CheckboxLine>
            I don't want to receive emails about solaceui feature updates
          </CheckboxLine>
          <CheckboxLine>{termsText}</CheckboxLine>
        </div>

        <button
          type="button"
          className="mt-9 flex h-12 w-full items-center justify-center rounded-[10px] border border-black/40 bg-black text-lg font-medium text-white transition-colors hover:bg-black/85 dark:border-white/40 dark:bg-white dark:text-black dark:hover:bg-white/85"
        >
          Submit
        </button>
      </form>
    </div>
  );
}

function SocialButton({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <button
      type="button"
      className="flex h-9 items-center justify-center gap-2 rounded-[8px] border border-black/25 bg-white px-3 text-sm leading-none text-black transition-colors hover:bg-black/[0.03] dark:border-white/20 dark:bg-white/5 dark:text-white dark:hover:bg-white/10"
    >
      <span className="shrink-0">{icon}</span>
      <span className="whitespace-nowrap">{label}</span>
    </button>
  );
}

function FieldBox({
  label,
  value,
  type = "text",
}: {
  label: string;
  value: string;
  type?: string;
}) {
  const [inputValue, setInputValue] = useState(value);
  const [isEditing, setIsEditing] = useState(false);

  return (
    <label className="flex h-11 items-center justify-between gap-4 rounded-[8px] border border-black/20 bg-white px-4 text-base leading-none dark:border-white/15 dark:bg-white/5">
      <input
        type={type}
        value={inputValue}
        aria-label={label}
        onFocus={() => {
          if (!isEditing) {
            setInputValue("");
            setIsEditing(true);
          }
        }}
        onChange={(event) => {
          setInputValue(event.target.value);
          setIsEditing(true);
        }}
        className="min-w-0 flex-1 truncate bg-transparent text-black/35 outline-none placeholder:text-black/35 dark:text-white/35 dark:placeholder:text-white/35"
      />
      {!isEditing && (
        <span className="shrink-0 text-black dark:text-white">{label}</span>
      )}
    </label>
  );
}

function CheckboxLine({ children }: { children: ReactNode }) {
  return (
    <label className="flex items-start gap-3">
      <span className="relative mt-0.5 size-3 shrink-0">
        <input
          type="checkbox"
          className="peer size-full appearance-none rounded-[2px] border border-black/25 bg-white checked:border-black checked:bg-black dark:border-white/30 dark:bg-white/5 dark:checked:border-white dark:checked:bg-white"
        />
        <svg
          viewBox="0 0 12 12"
          className="pointer-events-none absolute inset-0 hidden size-full p-px text-white peer-checked:block dark:text-black"
          fill="none"
          aria-hidden="true"
        >
          <path
            d="M3 6.2 5 8.1 9 3.9"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </span>
      <span>{children}</span>
    </label>
  );
}

function MidjourneyLogo({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      className={className}
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M5 25.5c5.4-3.3 9-9.7 9.8-18.8 5.2 5.5 8 11.8 8.8 18.8H5Z"
        stroke="currentColor"
        strokeWidth="1.4"
      />
      <path
        d="M8 23.5h18M10.5 20.5h12.8M12.7 17.5h8.6"
        stroke="currentColor"
        strokeWidth="1.2"
        strokeLinecap="round"
      />
      <path
        d="M14.9 6.8c-1.1 7.6.7 13.4 5.3 17"
        stroke="currentColor"
        strokeWidth="1.2"
        strokeLinecap="round"
      />
    </svg>
  );
}

function GoogleIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09Z"
        fill="#4285F4"
      />
      <path
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23Z"
        fill="#34A853"
      />
      <path
        d="M5.84 14.1c-.22-.66-.35-1.36-.35-2.1s.13-1.44.35-2.1V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l3.66-2.84Z"
        fill="#FBBC05"
      />
      <path
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84C6.71 7.3 9.14 5.38 12 5.38Z"
        fill="#EB4335"
      />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M17.05 12.54c-.03-3.02 2.47-4.47 2.58-4.54-1.41-2.06-3.6-2.34-4.38-2.37-1.86-.19-3.64 1.1-4.58 1.1-.95 0-2.42-1.07-3.98-1.04-2.05.03-3.94 1.19-4.99 3.02-2.13 3.69-.54 9.16 1.53 12.15 1.01 1.46 2.22 3.1 3.81 3.04 1.53-.06 2.11-.99 3.96-.99s2.37.99 3.99.96c1.65-.03 2.69-1.49 3.69-2.96 1.16-1.69 1.64-3.33 1.66-3.41-.04-.02-3.2-1.23-3.24-4.87ZM14.03 3.66c.84-1.02 1.41-2.43 1.25-3.84-1.21.05-2.68.81-3.55 1.83-.78.9-1.46 2.34-1.28 3.72 1.35.1 2.73-.69 3.58-1.71Z" />
    </svg>
  );
}
